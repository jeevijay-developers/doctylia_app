import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/logging/app_logger.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseDashboardRepository implements DashboardRepository {
  const SupabaseDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<DashboardSnapshot>> loadDashboard(String doctorId) {
    return RepositoryGuard.run(() async {
      try {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final format = DateFormat('yyyy-MM-dd');
        final todayText = format.format(today);
        final weekAgo = format.format(today.subtract(const Duration(days: 7)));
        final twoWeeksAgo = format.format(
          today.subtract(const Duration(days: 14)),
        );
        final thirtyDaysAgo = format.format(
          today.subtract(const Duration(days: 29)),
        );
        final previousThirtyDaysAgo = format.format(
          today.subtract(const Duration(days: 59)),
        );

        // These futures are started together to mirror DashboardHome.tsx's
        // Promise.all. Revenue deliberately uses invoices.amount.
        final results = await Future.wait<dynamic>([
          _trace('appointment count', () async {
            return _client
                .from('appointments')
                .count(CountOption.exact)
                .eq('doctor_id', doctorId);
          }),
          _trace('patient count', () async {
            return _client
                .from('patients')
                .count(CountOption.exact)
                .eq('doctor_id', doctorId);
          }),
          _trace('all invoices', () async {
            return _client
                .from('invoices')
                .select('amount')
                .eq('doctor_id', doctorId);
          }),
          _trace('today appointments', () async {
            return _client
                .from('appointments')
                .select(
                  'id, patient_name, service_name, appointment_type, date, '
                  'time_slot, status',
                )
                .eq('doctor_id', doctorId)
                .eq('date', todayText)
                .order('time_slot');
          }),
          _trace('weekly invoices', () async {
            return _client
                .from('invoices')
                .select('amount')
                .eq('doctor_id', doctorId)
                .gte('created_at', '${weekAgo}T00:00:00');
          }),
          _trace('previous week appointments', () async {
            return _client
                .from('appointments')
                .count(CountOption.exact)
                .eq('doctor_id', doctorId)
                .gte('date', twoWeeksAgo)
                .lt('date', weekAgo);
          }),
          _trace('monthly invoices', () async {
            return _client
                .from('invoices')
                .select('amount, created_at')
                .eq('doctor_id', doctorId)
                .gte('created_at', '${thirtyDaysAgo}T00:00:00');
          }),
          _trace('appointment cap', () async {
            return _client.rpc(
              'get_appointment_cap_usage',
              params: {'_doctor_id': doctorId},
            );
          }),
          _trace('dashboard profile', () async {
            return _client
                .from('profiles')
                .select('slug, onboarding_completed, plan_status, trial_end')
                .eq('id', doctorId)
                .maybeSingle();
          }),
          _trace('review ratings', () async {
            return _client
                .from('reviews')
                .select('rating')
                .eq('doctor_id', doctorId);
          }),
          _trace('previous monthly invoices', () async {
            return _client
                .from('invoices')
                .select('amount')
                .eq('doctor_id', doctorId)
                .gte('created_at', '${previousThirtyDaysAgo}T00:00:00')
                .lt('created_at', '${thirtyDaysAgo}T00:00:00');
          }),
          _trace('new patients this week', () async {
            return _client
                .from('patients')
                .count(CountOption.exact)
                .eq('doctor_id', doctorId)
                .gte('created_at', '${weekAgo}T00:00:00');
          }),
          _trace('active patients this week', () async {
            return _client
                .from('patients')
                .count(CountOption.exact)
                .eq('doctor_id', doctorId)
                .gte('last_visit', weekAgo);
          }),
        ]);

        final totalAppointments = results[0] as int;
        final totalPatients = results[1] as int;
        final allInvoices = _rows(results[2]);
        final todayRows = _rows(results[3]);
        final weekInvoices = _rows(results[4]);
        final lastWeekAppointments = results[5] as int;
        final monthInvoices = _rows(results[6]);
        final capRows = _rows(results[7]);
        final profile = results[8] as Map<String, dynamic>?;
        final reviewRows = _rows(results[9]);
        final previousMonthInvoices = _rows(results[10]);
        final newPatientsThisWeek = results[11] as int;
        final activePatientsThisWeek = results[12] as int;
        final websiteSlug = _optionalText(profile?['slug']);

        final totalRevenue = _sumAmounts(allInvoices);
        final weekRevenue = _sumAmounts(weekInvoices);
        final reviewCount = reviewRows.length;
        final averageRating = reviewCount == 0
            ? 0.0
            : reviewRows.fold<double>(
                    0,
                    (sum, row) =>
                        sum + ((row['rating'] as num?)?.toDouble() ?? 0),
                  ) /
                  reviewCount;
        final revenueBuckets = <DateTime, double>{
          for (var daysAgo = 29; daysAgo >= 0; daysAgo--)
            today.subtract(Duration(days: daysAgo)): 0,
        };
        var monthlyRevenue = 0.0;
        for (final invoice in monthInvoices) {
          final amount = _amount(invoice);
          monthlyRevenue += amount;
          final createdAt = DateTime.parse(
            invoice['created_at'] as String,
          ).toLocal();
          final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
          if (revenueBuckets.containsKey(day)) {
            revenueBuckets[day] = revenueBuckets[day]! + amount;
          }
        }
        final previousMonthRevenue = _sumAmounts(previousMonthInvoices);
        final revenueGrowthPercent = previousMonthRevenue <= 0
            ? null
            : ((monthlyRevenue - previousMonthRevenue) / previousMonthRevenue) *
                  100;

        final cap = capRows.isEmpty ? null : capRows.first;
        return DashboardSnapshot(
          stats: DashboardStats(
            appointments: totalAppointments,
            patients: totalPatients,
            totalRevenue: totalRevenue,
            todayAppointments: todayRows.length,
            weekRevenue: weekRevenue,
            lastWeekAppointments: lastWeekAppointments,
            reviewCount: reviewCount,
            averageRating: averageRating,
            monthlyPaidInvoices: monthInvoices.length,
            revenueGrowthPercent: revenueGrowthPercent,
            newPatientsThisWeek: newPatientsThisWeek,
            activePatientsThisWeek: activePatientsThisWeek,
          ),
          todaySchedule: todayRows
              .where(
                (row) => DashboardAppointmentMapper.isOutstandingStatus(
                  row['status'] as String?,
                ),
              )
              .take(6)
              .map(DashboardAppointmentMapper.fromJson)
              .toList(growable: false),
          revenueSeries: revenueBuckets.entries
              .map((entry) => RevenuePoint(day: entry.key, amount: entry.value))
              .toList(growable: false),
          monthlyRevenue: monthlyRevenue,
          // DashboardHome.tsx treats a profile slug as the source of truth for
          // whether the public booking link can be shared.
          websiteIsLive: websiteSlug != null,
          websiteSlug: websiteSlug,
          appointmentsUsed: (cap?['appointments_used'] as num?)?.toInt() ?? 0,
          appointmentsCap: (cap?['appointments_cap'] as num?)?.toInt(),
          isPremium: cap?['is_premium'] as bool? ?? false,
          planStatus: _planStatus(profile?['plan_status'] as String?),
          trialEnd: _optionalDate(profile?['trial_end']),
        );
      } catch (error, stackTrace) {
        throw _mapFailure(error, stackTrace);
      }
    });
  }

  @override
  Stream<void> watchDashboardChanges(String doctorId) {
    late final RealtimeChannel channel;
    late final StreamController<void> controller;
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'doctor_id',
      value: doctorId,
    );

    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('mobile-dashboard-$doctorId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'appointments',
              filter: filter,
              callback: (_) => controller.add(null),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'patients',
              filter: filter,
              callback: (_) => controller.add(null),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'invoices',
              filter: filter,
              callback: (_) => controller.add(null),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'reviews',
              filter: filter,
              callback: (_) => controller.add(null),
            )
            .subscribe();
      },
      onCancel: () async {
        await _client.removeChannel(channel);
      },
    );
    return controller.stream;
  }

  static List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) return const [];
    return value.cast<Map<String, dynamic>>();
  }

  static Future<dynamic> _trace(
    String name,
    Future<dynamic> Function() query,
  ) async {
    try {
      return await query();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Dashboard query failed: $name',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static double _amount(Map<String, dynamic> row) =>
      (row['amount'] as num?)?.toDouble() ?? 0;

  static double _sumAmounts(List<Map<String, dynamic>> rows) =>
      rows.fold(0, (sum, row) => sum + _amount(row));

  static DateTime? _optionalDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static String? _optionalText(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }

  static PlanStatus? _planStatus(String? value) => switch (value) {
    'trial' => PlanStatus.trial,
    'active' => PlanStatus.active,
    'expired' => PlanStatus.expired,
    'cancelled' => PlanStatus.cancelled,
    _ => null,
  };

  static AppFailure _mapFailure(Object error, StackTrace stackTrace) {
    final text = error.toString().toLowerCase();
    if (text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection timed out') ||
        text.contains('network is unreachable')) {
      return NetworkFailure(cause: error, stackTrace: stackTrace);
    }
    if (error is PostgrestException && error.code == '42501') {
      return const PermissionFailure();
    }
    return ServerFailure(cause: error, stackTrace: stackTrace);
  }
}

abstract final class DashboardAppointmentMapper {
  static bool isOutstandingStatus(String? status) =>
      status == 'pending' || status == 'confirmed';

  static DashboardAppointment fromJson(Map<String, dynamic> json) {
    final date = json['date'] as String?;
    final rawTime = json['time_slot'] as String?;
    final time = rawTime?.trim();
    final scheduledAt = DateTime.tryParse(
      '${date ?? DateFormat('yyyy-MM-dd').format(DateTime.now())}'
      'T${time == null || time.isEmpty ? '00:00:00' : time}',
    );
    return DashboardAppointment(
      id: json['id'] as String? ?? '',
      patientName: _textOr(json['patient_name'], 'Patient'),
      serviceName: _textOr(json['service_name'], 'Consultation'),
      appointmentType: _textOr(json['appointment_type'], 'clinic'),
      scheduledAt: scheduledAt ?? DateTime.now(),
      status: _status(json['status'] as String?),
      timeSlot: time == null || time.isEmpty ? null : time,
    );
  }

  static String _textOr(Object? value, String fallback) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? fallback : text;
  }

  static DashboardAppointmentStatus _status(String? value) => switch (value) {
    'pending' => DashboardAppointmentStatus.pending,
    'confirmed' => DashboardAppointmentStatus.confirmed,
    'completed' => DashboardAppointmentStatus.completed,
    'cancelled' => DashboardAppointmentStatus.cancelled,
    'no_show' => DashboardAppointmentStatus.noShow,
    _ => DashboardAppointmentStatus.pending,
  };
}
