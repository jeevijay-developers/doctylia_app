import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/logging/app_logger.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';
import 'package:doctylia_app/features/billing/domain/repositories/billing_repository.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseBillingRepository implements BillingRepository {
  SupabaseBillingRepository(this._client);

  final SupabaseClient _client;
  int _watcherSequence = 0;
  Future<void>? _invoiceSync;

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<PageResult<BillingTransaction>>> listTransactions(
    PageRequest page,
    BillingQuery query,
  ) => _guard(() => _listTransactions(page, query));

  Future<PageResult<BillingTransaction>> _listTransactions(
    PageRequest page,
    BillingQuery query,
  ) async {
    final term = _searchTerm(query.search);
    final date = DateFormat('yyyy-MM-dd');
    dynamic request = _client
        .from('appointments')
        .select(
          'id,patient_name,service_name,date,time_slot,amount,payment_status,status,payment_gateway',
        )
        .eq('doctor_id', _doctorId);
    if (query.paymentStatus != null) {
      request = request.eq(
        'payment_status',
        _paymentStatusValue(query.paymentStatus!),
      );
    }
    if (query.startDate != null) {
      request = request.gte('date', date.format(query.startDate!));
    }
    if (query.endDateExclusive != null) {
      request = request.lt('date', date.format(query.endDateExclusive!));
    }
    if (term.isNotEmpty) {
      request = request.or(
        'patient_name.ilike.%$term%,service_name.ilike.%$term%',
      );
    }
    final rows =
        (await request
                    .order('date', ascending: false)
                    .order('time_slot', ascending: false)
                    .range(page.offset, page.inclusiveRangeEnd)
                as List)
            .cast<Map<String, dynamic>>()
            .map(_transaction)
            .toList(growable: false);
    return PageResult.fromLookahead(rows: rows, request: page);
  }

  @override
  Future<Result<List<BillingTransaction>>> exportTransactions(
    BillingQuery query,
  ) => _guard(() async {
    final rows = <BillingTransaction>[];
    var request = const PageRequest(limit: 100);
    while (true) {
      final page = await _listTransactions(request, query);
      rows.addAll(page.items);
      if (!page.hasMore) return rows;
      request = PageRequest(offset: page.nextOffset!, limit: 100);
    }
  });

  @override
  Future<Result<PageResult<Invoice>>> listInvoices(
    PageRequest page, {
    String search = '',
  }) => _guard(() async {
    await _ensureMissingInvoices();
    final term = _searchTerm(search);
    dynamic query = _client
        .from('invoices')
        .select()
        .eq('doctor_id', _doctorId);
    if (term.isNotEmpty) {
      query = query.or(
        'invoice_number.ilike.%$term%,patient_name.ilike.%$term%,service_name.ilike.%$term%',
      );
    }
    final rows =
        (await query
                    .order('created_at', ascending: false)
                    .range(page.offset, page.inclusiveRangeEnd)
                as List)
            .cast<Map<String, dynamic>>()
            .map(_invoice)
            .toList(growable: false);
    return PageResult.fromLookahead(rows: rows, request: page);
  });

  @override
  Future<Result<Invoice>> getInvoice(String id) => _guard(() async {
    final row = await _client
        .from('invoices')
        .select()
        .eq('id', id)
        .eq('doctor_id', _doctorId)
        .single();
    return _invoice(row);
  });

  @override
  Future<Result<BillingSummary>> getSummary() => _guard(() async {
    await _ensureMissingInvoices();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: now.weekday % 7));
    final monthStart = DateTime(now.year, now.month);
    final result = await Future.wait<dynamic>([
      _invoiceRevenue(todayStart, end: tomorrowStart),
      _invoiceRevenue(weekStart),
      _invoiceRevenue(monthStart),
      _client
          .from('appointments')
          .count(CountOption.exact)
          .eq('doctor_id', _doctorId)
          .eq('payment_status', 'paid'),
      for (final value in ['pending', 'pay_at_clinic', 'refunded'])
        _client
            .from('appointments')
            .count(CountOption.exact)
            .eq('doctor_id', _doctorId)
            .eq('payment_status', value),
    ]);
    return BillingSummary(
      todayRevenue: result[0] as double,
      weekRevenue: result[1] as double,
      monthRevenue: result[2] as double,
      paidCount: result[3] as int,
      pendingCount: result[4] as int,
      payAtClinicCount: result[5] as int,
      refundedCount: result[6] as int,
    );
  });

  Future<double> _invoiceRevenue(DateTime start, {DateTime? end}) async {
    dynamic query = _client
        .from('invoices')
        .select('amount')
        .eq('doctor_id', _doctorId)
        .gte('created_at', start.toUtc().toIso8601String());
    if (end != null) {
      query = query.lt('created_at', end.toUtc().toIso8601String());
    }
    final rows = (await query as List).cast<Map<String, dynamic>>();
    return rows.fold<double>(
      0,
      (sum, row) => sum + (row['amount'] as num).toDouble(),
    );
  }

  @override
  Stream<void> watchChanges() {
    final controller = StreamController<void>();
    final channel = _client.channel(
      'mobile-billing-$_doctorId-${_watcherSequence++}',
    );
    for (final table in ['appointments', 'invoices']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'doctor_id',
          value: _doctorId,
        ),
        callback: (_) => controller.add(null),
      );
    }
    channel.subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }

  Future<void> _ensureMissingInvoices() async {
    if (_invoiceSync != null) return _invoiceSync!;
    final operation = _generateMissingInvoices();
    _invoiceSync = operation;
    try {
      await operation;
    } finally {
      _invoiceSync = null;
    }
  }

  Future<void> _generateMissingInvoices() async {
    try {
      final missing = await _client
          .from('appointments')
          .select('id,patient_name,service_name,amount,invoices!left(id)')
          .eq('doctor_id', _doctorId)
          .eq('payment_status', 'paid')
          .isFilter('invoices', null);
      if (missing.isEmpty) return;
      final profile = await _client
          .from('profiles')
          .select('gst_registered,gstin')
          .eq('id', _doctorId)
          .maybeSingle();
      final year = DateTime.now().year;
      final prefix = 'INV-$year-';
      final existing = await _client
          .from('invoices')
          .select('invoice_number')
          .eq('doctor_id', _doctorId)
          .like('invoice_number', '$prefix%');
      var sequence = 0;
      for (final row in existing) {
        final value = int.tryParse(
          (row['invoice_number'] as String).substring(prefix.length),
        );
        if (value != null && value > sequence) sequence = value;
      }
      final gstRate = profile?['gst_registered'] == true ? 18.0 : 0.0;
      for (final appointment in missing) {
        sequence += 1;
        final amount = (appointment['amount'] as num?)?.toDouble() ?? 0;
        final gstAmount = double.parse(
          (amount * gstRate / 100).toStringAsFixed(2),
        );
        await _client.from('invoices').insert({
          'doctor_id': _doctorId,
          'appointment_id': appointment['id'],
          'invoice_number': '$prefix${sequence.toString().padLeft(4, '0')}',
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
    } catch (error, stackTrace) {
      // Web treats this backfill as best-effort; billing data should still load.
      AppLogger.error(
        'Billing invoice backfill failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static BillingTransaction _transaction(Map<String, dynamic> row) =>
      BillingTransaction(
        id: row['id'] as String,
        patientName: row['patient_name'] as String,
        serviceName: row['service_name'] as String,
        date: DateTime.parse(row['date'] as String),
        amount: (row['amount'] as num?)?.toDouble() ?? 0,
        paymentStatus: _paymentStatus(row['payment_status'] as String),
        appointmentStatus: row['status'] as String,
        isMock: row['payment_gateway'] == 'razorpay_mock',
      );

  static Invoice _invoice(Map<String, dynamic> row) => Invoice(
    id: row['id'] as String,
    invoiceNumber: row['invoice_number'] as String,
    patientName: row['patient_name'] as String,
    serviceName: row['service_name'] as String,
    amount: (row['amount'] as num).toDouble(),
    gstRate: (row['gst_rate'] as num).toDouble(),
    gstAmount: (row['gst_amount'] as num).toDouble(),
    totalAmount: (row['total_amount'] as num).toDouble(),
    status: row['status'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    appointmentId: row['appointment_id'] as String?,
    clinicGstin: row['clinic_gstin'] as String?,
  );

  static BillingPaymentStatus _paymentStatus(String value) => switch (value) {
    'paid' => BillingPaymentStatus.paid,
    'pending' => BillingPaymentStatus.pending,
    'refunded' => BillingPaymentStatus.refunded,
    'pay_at_clinic' => BillingPaymentStatus.payAtClinic,
    _ => throw StateError('Unsupported payment status: $value'),
  };
  static String _paymentStatusValue(BillingPaymentStatus status) =>
      switch (status) {
        BillingPaymentStatus.paid => 'paid',
        BillingPaymentStatus.pending => 'pending',
        BillingPaymentStatus.refunded => 'refunded',
        BillingPaymentStatus.payAtClinic => 'pay_at_clinic',
      };

  Future<Result<T>> _guard<T>(Future<T> Function() operation) =>
      RepositoryGuard.run(() async {
        try {
          return await operation();
        } catch (error, stackTrace) {
          if (error is AppFailure) rethrow;
          final message = error.toString().toLowerCase();
          if (error is TimeoutException ||
              message.contains('socketexception') ||
              message.contains('failed host lookup')) {
            throw NetworkFailure(cause: error, stackTrace: stackTrace);
          }
          if (error is PostgrestException && error.code == '42501') {
            throw const PermissionFailure();
          }
          throw ServerFailure(cause: error, stackTrace: stackTrace);
        }
      });

  static String _searchTerm(String value) =>
      value.replaceAll(RegExp(r'[,()%_]'), ' ').trim();
}
