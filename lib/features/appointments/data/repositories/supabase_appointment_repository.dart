import 'dart:async';
import 'dart:math';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/logging/app_logger.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment_query.dart';
import 'package:doctylia_app/features/appointments/domain/repositories/appointment_repository.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAppointmentRepository implements AppointmentRepository {
  SupabaseAppointmentRepository(this._client);

  final SupabaseClient _client;
  int _watcherSequence = 0;
  static const _columns =
      'id, patient_name, patient_phone, patient_age, patient_gender, '
      'patient_email, service_name, appointment_type, date, time_slot, '
      'status, payment_status, amount, token_number, chief_complaint, notes, '
      'reschedule_count, zoom_meeting_id, zoom_join_url, zoom_start_url';

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<PageResult<Appointment>>> list(
    PageRequest page,
    AppointmentQuery query,
  ) => _guard(() async {
    await _expireOverdue();
    dynamic rowsQuery = _applyFilters(
      _client.from('appointments').select(_columns).eq('doctor_id', _doctorId),
      query,
    );
    dynamic countQuery = _applyFilters(
      _client
          .from('appointments')
          .count(CountOption.exact)
          .eq('doctor_id', _doctorId),
      query,
    );
    final results = await Future.wait<dynamic>([
      rowsQuery
          .order('date', ascending: false)
          .order('time_slot')
          .range(page.offset, page.offset + page.limit - 1),
      countQuery,
    ]);
    final rows = (results[0] as List).cast<Map<String, dynamic>>();
    final total = results[1] as int;
    return PageResult(
      items: rows.map(AppointmentMapper.fromJson).toList(growable: false),
      hasMore: page.offset + rows.length < total,
      nextOffset: page.offset + rows.length < total
          ? page.offset + page.limit
          : null,
      totalCount: total,
    );
  });

  @override
  Future<Result<AppointmentSummary>> summary(AppointmentQuery query) =>
      _guard(() async {
        await _expireOverdue();
        final baseQuery = query.copyWith(clearStatus: true);
        final counts = await Future.wait<int>([
          _count(baseQuery),
          _count(baseQuery.copyWith(status: AppointmentStatus.pending)),
          _count(baseQuery.copyWith(status: AppointmentStatus.confirmed)),
          _count(baseQuery.copyWith(status: AppointmentStatus.completed)),
          _count(baseQuery.copyWith(status: AppointmentStatus.cancelled)),
          _count(baseQuery.copyWith(status: AppointmentStatus.noShow)),
        ]);
        return AppointmentSummary(
          total: counts[0],
          pending: counts[1],
          confirmed: counts[2],
          completed: counts[3],
          cancelled: counts[4],
          noShow: counts[5],
        );
      });

  Future<int> _count(AppointmentQuery query) async {
    final dynamic countQuery = _applyFilters(
      _client
          .from('appointments')
          .count(CountOption.exact)
          .eq('doctor_id', _doctorId),
      query,
    );
    return await countQuery as int;
  }

  dynamic _applyFilters(dynamic query, AppointmentQuery value) {
    final status = value.status;
    if (status == AppointmentStatus.pending) {
      // Web parity: "Pending" covers every upcoming, not-yet-seen booking,
      // including website bookings that were auto-confirmed after payment.
      query = query.inFilter('status', const ['pending', 'confirmed']);
    } else if (status != null) {
      query = query.eq('status', AppointmentMapper.status(status));
    }
    if (value.dateFrom != null) {
      query = query.gte('date', _date(value.dateFrom!));
    }
    if (value.dateTo != null) query = query.lte('date', _date(value.dateTo!));
    final term = value.search.replaceAll(RegExp(r'[,()%_]'), ' ').trim();
    if (term.isNotEmpty) {
      query = query.or(
        'patient_name.ilike.%$term%,patient_phone.ilike.%$term%,'
        'patient_email.ilike.%$term%,service_name.ilike.%$term%,'
        'token_number.ilike.%$term%',
      );
    }
    return query;
  }

  Future<void> _expireOverdue() async {
    final now = DateTime.now();
    await _client
        .from('appointments')
        .update({'status': 'no_show'})
        .eq('doctor_id', _doctorId)
        .inFilter('status', ['pending', 'confirmed'])
        .or(
          'date.lt.${_date(now)},and(date.eq.${_date(now)},'
          'time_slot.lt.${DateFormat('HH:mm').format(now)})',
        );
  }

  @override
  Future<Result<Appointment>> create(AppointmentDraft draft) =>
      _guard(() async {
        _validate(draft);
        // Slot availability is enforced atomically by the database trigger.
        // A separate read here was both race-prone and could prevent valid
        // appointments from reaching the insert at all.
        final row = await _client
            .from('appointments')
            .insert({
              'doctor_id': _doctorId,
              ..._draftJson(draft),
              'token_number': 'T${Random().nextInt(900) + 100}',
              'status': 'pending',
            })
            .select(_columns)
            .single();
        return AppointmentMapper.fromJson(row);
      });

  @override
  Future<Result<void>> update(String id, AppointmentDraft draft) =>
      _guard(() async {
        _validate(draft, allowPast: true);
        final current = await _appointmentRow(id);
        final oldDateTime = AppointmentMapper.dateTime(current);
        final wasWalkIn = current['time_slot'] == null;
        final moved =
            oldDateTime != draft.scheduledAt || wasWalkIn != draft.isWalkIn;
        if (moved && _isInPast(draft)) {
          throw const ValidationFailure(
            'Cannot reschedule an appointment into the past.',
          );
        }
        if (moved && !draft.isWalkIn) {
          await _ensureSlotAvailable(draft.scheduledAt, excludingId: id);
        }
        final values = _draftJson(draft);
        if (moved) {
          values['reschedule_count'] =
              ((current['reschedule_count'] as num?)?.toInt() ?? 0) + 1;
        }
        await _client
            .from('appointments')
            .update(values)
            .eq('id', id)
            .eq('doctor_id', _doctorId);
        if (moved && current['zoom_meeting_id'] != null) {
          await _syncZoom(id, 'update');
        }
      });

  @override
  Future<Result<void>> updatePaymentStatus(
    String id,
    AppointmentPaymentStatus status,
  ) => _guard(() async {
    await _client
        .from('appointments')
        .update({'payment_status': AppointmentMapper.paymentStatus(status)})
        .eq('id', id)
        .eq('doctor_id', _doctorId);
  });

  @override
  Future<Result<void>> updateStatus(String id, AppointmentStatus status) =>
      _guard(() async {
        final current = await _appointmentRow(id);
        await _client
            .from('appointments')
            .update({'status': AppointmentMapper.status(status)})
            .eq('id', id)
            .eq('doctor_id', _doctorId);

        if (status == AppointmentStatus.completed &&
            current['status'] != 'completed') {
          // These are intentionally client-side on web; preserve both effects.
          try {
            await _upsertPatientForCompletion(current);
          } catch (error, stackTrace) {
            AppLogger.error(
              'Patient visit sync failed after appointment completion',
              error: error,
              stackTrace: stackTrace,
            );
          }
          try {
            await _ensureInvoice(current);
          } catch (error, stackTrace) {
            AppLogger.error(
              'Invoice generation failed after appointment completion',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        if ((status == AppointmentStatus.cancelled ||
                status == AppointmentStatus.noShow) &&
            current['zoom_meeting_id'] != null) {
          await _syncZoom(id, 'delete');
        }
      });

  @override
  Future<Result<void>> reschedule(String id, DateTime scheduledAt) =>
      _guard(() async {
        final row = await _appointmentRow(id);
        final draft = AppointmentMapper.toDraft(
          AppointmentMapper.fromJson(row),
          scheduledAt: scheduledAt,
        );
        final result = await update(id, draft);
        result.fold(onSuccess: (_) {}, onFailure: (failure) => throw failure);
      });

  @override
  Future<Result<void>> delete(String id) => _guard(() async {
    final row = await _appointmentRow(id);
    if (row['zoom_meeting_id'] != null) await _syncZoom(id, 'delete');
    await _client
        .from('appointments')
        .delete()
        .eq('id', id)
        .eq('doctor_id', _doctorId);
  });

  @override
  Future<Result<void>> deleteMany(List<String> ids) => _guard(() async {
    if (ids.isEmpty) return;
    final rows = await _client
        .from('appointments')
        .select('id, zoom_meeting_id')
        .eq('doctor_id', _doctorId)
        .inFilter('id', ids);
    for (final row in rows) {
      if (row['zoom_meeting_id'] != null) {
        await _syncZoom(row['id'] as String, 'delete');
      }
    }
    await _client
        .from('appointments')
        .delete()
        .eq('doctor_id', _doctorId)
        .inFilter('id', ids);
  });

  @override
  Future<Result<ZoomMeetingLinks>> generateZoomMeeting(String id) =>
      _guard(() async {
        final response = await _client.functions
            .invoke(
              'create-zoom-meeting',
              body: {'appointment_id': id, 'action': 'create'},
            )
            .timeout(const Duration(seconds: 20));
        final data = response.data;
        if (data is! Map || data['error'] != null) {
          throw ServerFailure(cause: data is Map ? data['error'] : data);
        }
        final meetingId = data['meeting_id']?.toString();
        final joinUrl = data['join_url'] as String?;
        final startUrl = data['start_url'] as String?;
        if (meetingId == null || joinUrl == null || startUrl == null) {
          throw const ServerFailure();
        }
        return ZoomMeetingLinks(
          meetingId: meetingId,
          joinUrl: joinUrl,
          startUrl: startUrl,
        );
      });

  Future<void> _syncZoom(String id, String action) async {
    try {
      await _client.functions
          .invoke(
            'create-zoom-meeting',
            body: {'appointment_id': id, 'action': action},
          )
          .timeout(const Duration(seconds: 20));
    } catch (error, stackTrace) {
      // Web treats update/delete synchronization as best-effort.
      AppLogger.error(
        'Zoom $action synchronization failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Map<String, dynamic>> _appointmentRow(String id) async => _client
      .from('appointments')
      .select(_columns)
      .eq('id', id)
      .eq('doctor_id', _doctorId)
      .single();

  Future<void> _ensureSlotAvailable(
    DateTime scheduledAt, {
    String? excludingId,
  }) async {
    final settings = await _client
        .from('website_settings')
        .select('max_per_slot')
        .eq('doctor_id', _doctorId)
        .maybeSingle();
    final cap = (settings?['max_per_slot'] as num?)?.toInt() ?? 1;
    dynamic query = _client
        .from('appointments')
        .count(CountOption.exact)
        .eq('doctor_id', _doctorId)
        .eq('date', _date(scheduledAt))
        .eq('time_slot', DateFormat('HH:mm').format(scheduledAt))
        .neq('status', 'cancelled');
    if (excludingId != null) query = query.neq('id', excludingId);
    final taken = await query as int;
    if (taken >= cap) {
      throw const ConflictFailure('That appointment slot is full.');
    }
  }

  Future<void> _upsertPatientForCompletion(
    Map<String, dynamic> appointment,
  ) async {
    final phone = appointment['patient_phone'] as String?;
    if (phone == null || phone.isEmpty) return;
    final name = (appointment['patient_name'] as String).trim();
    final candidates = await _client
        .from('patients')
        .select('id, name, email, total_visits, first_visit')
        .eq('doctor_id', _doctorId)
        .eq('phone', phone);
    Map<String, dynamic>? existing;
    for (final candidate in candidates) {
      if ((candidate['name'] as String? ?? '').trim().toLowerCase() ==
          name.toLowerCase()) {
        existing = candidate;
        break;
      }
    }
    if (existing != null) {
      await _client
          .from('patients')
          .update({
            'total_visits':
                ((existing['total_visits'] as num?)?.toInt() ?? 0) + 1,
            'last_visit': appointment['date'],
            'first_visit': existing['first_visit'] ?? appointment['date'],
            if (existing['email'] == null)
              'email': appointment['patient_email'],
          })
          .eq('id', existing['id']);
    } else {
      await _client.from('patients').insert({
        'doctor_id': _doctorId,
        'name': name,
        'phone': phone,
        'first_visit': appointment['date'],
        'last_visit': appointment['date'],
        'total_visits': 1,
        'age': appointment['patient_age'],
        'gender': appointment['patient_gender'],
        'email': appointment['patient_email'],
      });
    }
  }

  Future<void> _ensureInvoice(Map<String, dynamic> appointment) async {
    final appointmentId = appointment['id'] as String;
    final exists = await _client
        .from('invoices')
        .select('id')
        .eq('appointment_id', appointmentId)
        .maybeSingle();
    if (exists != null) return;
    final profile = await _client
        .from('profiles')
        .select('gst_registered, gstin')
        .eq('id', _doctorId)
        .maybeSingle();
    final year = DateTime.now().year;
    final prefix = 'INV-$year-';
    final invoices = await _client
        .from('invoices')
        .select('invoice_number')
        .eq('doctor_id', _doctorId)
        .like('invoice_number', '$prefix%');
    var maxSequence = 0;
    for (final invoice in invoices) {
      final sequence = int.tryParse(
        (invoice['invoice_number'] as String).substring(prefix.length),
      );
      if (sequence != null && sequence > maxSequence) maxSequence = sequence;
    }
    final amount = (appointment['amount'] as num?)?.toDouble() ?? 0;
    final gstRate = profile?['gst_registered'] == true ? 18.0 : 0.0;
    final gstAmount = double.parse((amount * gstRate / 100).toStringAsFixed(2));
    await _client.from('invoices').insert({
      'doctor_id': _doctorId,
      'appointment_id': appointmentId,
      'invoice_number':
          '$prefix${(maxSequence + 1).toString().padLeft(4, '0')}',
      'patient_name': appointment['patient_name'],
      'service_name': appointment['service_name'],
      'amount': amount,
      'gst_rate': gstRate,
      'gst_amount': gstAmount,
      'total_amount': amount + gstAmount,
      'clinic_gstin': profile?['gstin'],
      'status': 'generated',
    });
  }

  Map<String, dynamic> _draftJson(AppointmentDraft draft) => {
    'patient_name': draft.patientName.trim(),
    'patient_phone': _normalizePhone(draft.patientPhone),
    'patient_age': draft.patientAge,
    'patient_gender': _emptyToNull(draft.patientGender),
    'patient_email': _emptyToNull(draft.patientEmail),
    'service_name': draft.serviceName.trim().isEmpty
        ? 'Consultation'
        : draft.serviceName.trim(),
    'appointment_type': draft.type == AppointmentType.online
        ? 'online'
        : 'clinic',
    'date': _date(draft.scheduledAt),
    'time_slot': draft.isWalkIn
        ? null
        : DateFormat('HH:mm').format(draft.scheduledAt),
    // appointments.amount is an integer column: sending a Dart double
    // ("500.0") makes PostgREST reject the whole insert/update with 22P02.
    'amount': draft.amount.round(),
    'chief_complaint': _emptyToNull(draft.chiefComplaint),
    'notes': _emptyToNull(draft.notes),
    'payment_status': AppointmentMapper.paymentStatus(draft.paymentStatus),
  };

  void _validate(AppointmentDraft draft, {bool allowPast = false}) {
    if (draft.patientName.trim().isEmpty) {
      throw const ValidationFailure('Patient name is required.');
    }
    final digits = draft.patientPhone.replaceAll(RegExp(r'\D'), '');
    if (!(digits.length == 10 ||
        (digits.length == 12 && digits.startsWith('91')))) {
      throw const ValidationFailure(
        'Enter a valid 10-digit Indian phone number.',
      );
    }
    if (draft.amount < 0) {
      throw const ValidationFailure('Amount cannot be negative.');
    }
    final age = draft.patientAge;
    if (age != null && (age < 0 || age > 120)) {
      throw const ValidationFailure('Age must be between 0 and 120.');
    }
    final email = draft.patientEmail?.trim() ?? '';
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw const ValidationFailure('Enter a valid email address.');
    }
    if (!allowPast && _isInPast(draft)) {
      throw const ValidationFailure(
        'Cannot book an appointment for a past date or time slot.',
      );
    }
  }

  static bool _isInPast(AppointmentDraft draft) {
    final now = DateTime.now();
    if (!draft.isWalkIn) return draft.scheduledAt.isBefore(now);
    final day = draft.scheduledAt;
    return DateTime(
      day.year,
      day.month,
      day.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
  }

  @override
  Stream<void> watchChanges() {
    late RealtimeChannel channel;
    late StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            // Unique per watcher: the list rebuilds on every filter change and
            // removing a same-named channel would also drop the new one.
            .channel('mobile-appointments-$_doctorId-${_watcherSequence++}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'appointments',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'doctor_id',
                value: _doctorId,
              ),
              callback: (_) => controller.add(null),
            )
            .subscribe();
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }

  Future<Result<T>> _guard<T>(Future<T> Function() operation) =>
      RepositoryGuard.run(() async {
        try {
          return await operation();
        } catch (error, stackTrace) {
          if (error is AppFailure) rethrow;
          AppLogger.error(
            'Appointment repository operation failed',
            error: error,
            stackTrace: stackTrace,
          );
          throw _mapFailure(error, stackTrace);
        }
      });

  static AppFailure _mapFailure(Object error, StackTrace stackTrace) {
    final text = error.toString().toLowerCase();
    if (error is TimeoutException ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable')) {
      return NetworkFailure(cause: error, stackTrace: stackTrace);
    }
    if (text.contains('monthly_appointment_cap_reached')) {
      return const PlanRestrictedFailure('more monthly appointments');
    }
    if (text.contains('slot_full')) {
      return ConflictFailure('That appointment slot is full.', cause: error);
    }
    if (text.contains('slot_in_past')) {
      return const ValidationFailure(
        'That time has already passed. Please choose a later slot.',
      );
    }
    if (error is PostgrestException && error.code == '23502') {
      return const ValidationFailure(
        'Please complete all required appointment details.',
      );
    }
    if (error is PostgrestException && error.code == '23514') {
      return const ValidationFailure(
        'Check the appointment date, time, age, and payment details.',
      );
    }
    if (error is PostgrestException && error.code == '42501') {
      return const PermissionFailure();
    }
    return ServerFailure(cause: error, stackTrace: stackTrace);
  }

  static String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  static String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '91$digits';
    return '+$digits';
  }

  static String? _emptyToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

abstract final class AppointmentMapper {
  static Appointment fromJson(Map<String, dynamic> row) => Appointment(
    id: row['id'] as String,
    patientName: row['patient_name'] as String,
    patientPhone: row['patient_phone'] as String? ?? '',
    patientAge: (row['patient_age'] as num?)?.toInt(),
    patientGender: row['patient_gender'] as String?,
    patientEmail: row['patient_email'] as String?,
    serviceName: row['service_name'] as String? ?? 'Consultation',
    scheduledAt: dateTime(row),
    isWalkIn: row['time_slot'] == null,
    status: _status(row['status'] as String?),
    paymentStatus: _paymentStatus(row['payment_status'] as String?),
    amount: (row['amount'] as num?)?.toDouble() ?? 0,
    type: row['appointment_type'] == 'online'
        ? AppointmentType.online
        : AppointmentType.clinic,
    tokenNumber: row['token_number'] as String?,
    chiefComplaint: row['chief_complaint'] as String?,
    notes: row['notes'] as String?,
    rescheduleCount: (row['reschedule_count'] as num?)?.toInt() ?? 0,
    zoomMeetingId: row['zoom_meeting_id']?.toString(),
    zoomJoinUrl: row['zoom_join_url'] as String?,
    zoomStartUrl: row['zoom_start_url'] as String?,
  );

  /// Walk-ins (created on web) have a null `time_slot`; they map to midnight
  /// of their date instead of crashing the whole page parse.
  static DateTime dateTime(Map<String, dynamic> row) {
    final slot = row['time_slot'] as String?;
    return DateTime.parse(
      slot == null || slot.isEmpty ? '${row['date']}' : '${row['date']}T$slot',
    );
  }

  static AppointmentDraft toDraft(Appointment value, {DateTime? scheduledAt}) =>
      AppointmentDraft(
        patientName: value.patientName,
        patientPhone: value.patientPhone,
        serviceName: value.serviceName,
        scheduledAt: scheduledAt ?? value.scheduledAt,
        isWalkIn: scheduledAt == null && value.isWalkIn,
        amount: value.amount,
        type: value.type,
        patientAge: value.patientAge,
        patientGender: value.patientGender,
        patientEmail: value.patientEmail,
        chiefComplaint: value.chiefComplaint,
        notes: value.notes,
        paymentStatus: value.paymentStatus,
      );

  static String status(AppointmentStatus value) => switch (value) {
    AppointmentStatus.pending => 'pending',
    AppointmentStatus.confirmed => 'confirmed',
    AppointmentStatus.completed => 'completed',
    AppointmentStatus.cancelled => 'cancelled',
    AppointmentStatus.noShow => 'no_show',
  };

  static String paymentStatus(AppointmentPaymentStatus value) =>
      switch (value) {
        AppointmentPaymentStatus.pending => 'pending',
        AppointmentPaymentStatus.paid => 'paid',
        AppointmentPaymentStatus.refunded => 'refunded',
        AppointmentPaymentStatus.payAtClinic => 'pay_at_clinic',
      };

  // Unknown values fall back like the web's `statusConfig[x] || pending`
  // rather than failing the entire list for one unexpected row.
  static AppointmentStatus _status(String? value) => switch (value) {
    'confirmed' => AppointmentStatus.confirmed,
    'completed' => AppointmentStatus.completed,
    'cancelled' => AppointmentStatus.cancelled,
    'no_show' => AppointmentStatus.noShow,
    _ => AppointmentStatus.pending,
  };

  static AppointmentPaymentStatus _paymentStatus(String? value) =>
      switch (value) {
        'paid' => AppointmentPaymentStatus.paid,
        'refunded' => AppointmentPaymentStatus.refunded,
        'pay_at_clinic' => AppointmentPaymentStatus.payAtClinic,
        _ => AppointmentPaymentStatus.pending,
      };
}
