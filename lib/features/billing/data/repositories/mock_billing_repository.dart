import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';
import 'package:doctylia_app/features/billing/domain/repositories/billing_repository.dart';

final class MockBillingRepository implements BillingRepository {
  MockBillingRepository()
    : _transactions = _seedTransactions(),
      _invoices = _seedInvoices();
  final List<BillingTransaction> _transactions;
  final List<Invoice> _invoices;

  @override
  Future<Result<BillingSummary>> getSummary() => RepositoryGuard.run(() {
    final now = DateTime.now();
    bool sameDay(DateTime value) =>
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    final week = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday % 7));
    final month = DateTime(now.year, now.month);
    double total(Iterable<Invoice> rows) =>
        rows.fold(0, (sum, row) => sum + row.amount);
    int count(BillingPaymentStatus status) =>
        _transactions.where((row) => row.paymentStatus == status).length;
    return BillingSummary(
      todayRevenue: total(_invoices.where((row) => sameDay(row.createdAt))),
      weekRevenue: total(
        _invoices.where((row) => !row.createdAt.isBefore(week)),
      ),
      monthRevenue: total(
        _invoices.where((row) => !row.createdAt.isBefore(month)),
      ),
      paidCount: count(BillingPaymentStatus.paid),
      pendingCount: count(BillingPaymentStatus.pending),
      payAtClinicCount: count(BillingPaymentStatus.payAtClinic),
      refundedCount: count(BillingPaymentStatus.refunded),
    );
  });

  @override
  Future<Result<PageResult<BillingTransaction>>> listTransactions(
    PageRequest page,
    BillingQuery query,
  ) => RepositoryGuard.run(() {
    final term = query.search.trim().toLowerCase();
    final rows =
        _transactions
            .where(
              (row) =>
                  (term.isEmpty ||
                      row.patientName.toLowerCase().contains(term) ||
                      row.serviceName.toLowerCase().contains(term)) &&
                  (query.paymentStatus == null ||
                      row.paymentStatus == query.paymentStatus) &&
                  (query.startDate == null ||
                      !row.date.isBefore(query.startDate!)) &&
                  (query.endDateExclusive == null ||
                      row.date.isBefore(query.endDateExclusive!)),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return _page(rows, page);
  });

  @override
  Future<Result<List<BillingTransaction>>> exportTransactions(
    BillingQuery query,
  ) => RepositoryGuard.run(() {
    final term = query.search.trim().toLowerCase();
    return _transactions
        .where(
          (row) =>
              (term.isEmpty ||
                  row.patientName.toLowerCase().contains(term) ||
                  row.serviceName.toLowerCase().contains(term)) &&
              (query.paymentStatus == null ||
                  row.paymentStatus == query.paymentStatus) &&
              (query.startDate == null ||
                  !row.date.isBefore(query.startDate!)) &&
              (query.endDateExclusive == null ||
                  row.date.isBefore(query.endDateExclusive!)),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  });

  @override
  Future<Result<PageResult<Invoice>>> listInvoices(
    PageRequest page, {
    String search = '',
  }) => RepositoryGuard.run(() {
    final term = search.trim().toLowerCase();
    final rows =
        _invoices
            .where(
              (row) =>
                  term.isEmpty ||
                  row.invoiceNumber.toLowerCase().contains(term) ||
                  row.patientName.toLowerCase().contains(term) ||
                  row.serviceName.toLowerCase().contains(term),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _page(rows, page);
  });

  PageResult<T> _page<T>(List<T> rows, PageRequest request) {
    final end = (request.offset + request.limit + 1).clamp(0, rows.length);
    final lookahead = request.offset >= rows.length
        ? <T>[]
        : rows.sublist(request.offset, end);
    return PageResult.fromLookahead(
      rows: lookahead,
      request: request,
      totalCount: rows.length,
    );
  }

  @override
  Future<Result<Invoice>> getInvoice(String id) =>
      RepositoryGuard.run(() => _invoices.firstWhere((row) => row.id == id));
  @override
  Stream<void> watchChanges() => const Stream.empty();
}

List<BillingTransaction> _seedTransactions() {
  final now = DateTime.now();
  const names = ['Ananya Sharma', 'Rohan Mehta', 'Meera Kapoor', 'Kabir Singh'];
  const services = ['General Consultation', 'Follow-up', 'Online Consultation'];
  return List.generate(38, (index) {
    final status = BillingPaymentStatus.values[index % 4];
    return BillingTransaction(
      id: 'transaction-$index',
      patientName: names[index % names.length],
      serviceName: services[index % services.length],
      date: now.subtract(Duration(days: index)),
      amount: 700 + (index % 4) * 100,
      paymentStatus: status,
      appointmentStatus: status == BillingPaymentStatus.refunded
          ? 'cancelled'
          : status == BillingPaymentStatus.paid
          ? 'completed'
          : 'confirmed',
      isMock: index % 7 == 0,
    );
  });
}

List<Invoice> _seedInvoices() {
  final now = DateTime.now();
  const names = ['Ananya Sharma', 'Rohan Mehta', 'Meera Kapoor', 'Kabir Singh'];
  return List.generate(27, (index) {
    final amount = 700.0 + (index % 4) * 100;
    final gstRate = index.isEven ? 18.0 : 0.0;
    final gstAmount = amount * gstRate / 100;
    return Invoice(
      id: 'invoice-$index',
      invoiceNumber:
          'INV-${now.year}-${(index + 1).toString().padLeft(4, '0')}',
      patientName: names[index % names.length],
      serviceName: index.isEven ? 'General Consultation' : 'Follow-up',
      amount: amount,
      gstRate: gstRate,
      gstAmount: gstAmount,
      totalAmount: amount + gstAmount,
      clinicGstin: gstRate > 0 ? '27ABCDE1234F1Z5' : null,
      status: 'generated',
      createdAt: now.subtract(Duration(days: index * 2)),
      appointmentId: 'appointment-$index',
    );
  });
}
