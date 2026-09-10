import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/billing/data/repositories/mock_billing_repository.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paginates transactions and invoices with lookahead', () async {
    final repo = MockBillingRepository();
    final transactions =
        (await repo.listTransactions(const PageRequest(), const BillingQuery())
                as Success)
            .value;
    final invoices =
        (await repo.listInvoices(const PageRequest()) as Success).value;
    expect(transactions.items, hasLength(20));
    expect(transactions.hasMore, isTrue);
    expect(invoices.items, hasLength(20));
    expect(invoices.hasMore, isTrue);
  });

  test(
    'filters payment status and computes persisted revenue summary',
    () async {
      final repo = MockBillingRepository();
      final paid =
          (await repo.listTransactions(
                    const PageRequest(),
                    const BillingQuery(
                      paymentStatus: BillingPaymentStatus.paid,
                    ),
                  )
                  as Success)
              .value;
      expect(
        paid.items,
        everyElement(
          predicate<BillingTransaction>(
            (row) => row.paymentStatus == BillingPaymentStatus.paid,
          ),
        ),
      );
      final summary =
          (await repo.getSummary() as Success).value as BillingSummary;
      expect(summary.monthRevenue, greaterThanOrEqualTo(summary.weekRevenue));
      expect(summary.paidCount, 10);
    },
  );

  test('invoice search includes service names like the web query', () async {
    final repo = MockBillingRepository();

    final page =
        (await repo.listInvoices(
                  const PageRequest(),
                  search: 'General Consultation',
                )
                as Success)
            .value;

    expect(page.items, isNotEmpty);
    expect(
      page.items,
      everyElement(
        predicate<Invoice>(
          (invoice) => invoice.serviceName == 'General Consultation',
        ),
      ),
    );
  });

  test(
    'transaction date range matches the web month and date filters',
    () async {
      final repo = MockBillingRepository();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final page =
          (await repo.listTransactions(
                    const PageRequest(),
                    BillingQuery(
                      startDate: today,
                      endDateExclusive: today.add(const Duration(days: 1)),
                    ),
                  )
                  as Success)
              .value;

      expect(page.items, hasLength(1));
      expect(page.items.single.date.day, today.day);
    },
  );
}
