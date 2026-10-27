import 'dart:async';

import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/billing/domain/entities/billing_models.dart';
import 'package:doctylia_app/features/billing/domain/repositories/billing_repository.dart';
import 'package:doctylia_app/features/billing/presentation/providers/billing_providers.dart';
import 'package:doctylia_app/features/billing/presentation/screens/billing_screen.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_access_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_preferences_store.dart';

final _today = DateUtils.dateOnly(DateTime.now());

BillingTransaction _tx(
  String id,
  String name,
  BillingPaymentStatus status, {
  int dayOffset = 0,
}) => BillingTransaction(
  id: id,
  patientName: name,
  serviceName: 'Cardiology Consultation',
  date: _today.add(Duration(days: dayOffset)),
  amount: 1200,
  paymentStatus: status,
  appointmentStatus: 'confirmed',
);

final _transactions = [
  _tx('paid', 'Pooja Paid', BillingPaymentStatus.paid),
  // Pending and the appointment already happened → derived "Overdue".
  _tx('late', 'Omar Overdue', BillingPaymentStatus.pending, dayOffset: -1),
  _tx('soon', 'Priya Pending', BillingPaymentStatus.pending, dayOffset: 2),
  _tx('clinic', 'Kiran Clinic', BillingPaymentStatus.payAtClinic),
  _tx('refund', 'Ravi Refund', BillingPaymentStatus.refunded),
];

/// Honors the status/date filters the screen sends; [gate] holds the first
/// transactions load open; queries are recorded for assertions.
final class _FakeRepository implements BillingRepository {
  _FakeRepository({this.gate});

  final Completer<void>? gate;
  final queries = <BillingQuery>[];

  @override
  Future<Result<BillingSummary>> getSummary() async => const Success(
    BillingSummary(
      todayRevenue: 2400,
      weekRevenue: 9600,
      monthRevenue: 48250,
      paidCount: 1,
      pendingCount: 2,
      payAtClinicCount: 1,
      refundedCount: 1,
    ),
  );

  @override
  Future<Result<PageResult<BillingTransaction>>> listTransactions(
    PageRequest page,
    BillingQuery query,
  ) async {
    queries.add(query);
    await gate?.future;
    final start = query.startDate;
    final end = query.endDateExclusive;
    final rows = _transactions
        .where(
          (t) =>
              query.paymentStatus == null ||
              t.paymentStatus == query.paymentStatus,
        )
        .where((t) => start == null || !t.date.isBefore(start))
        .where((t) => end == null || t.date.isBefore(end))
        .toList();
    return Success(PageResult(items: rows, hasMore: false));
  }

  @override
  Future<Result<PageResult<Invoice>>> listInvoices(
    PageRequest page, {
    String search = '',
  }) async => Success(
    PageResult(
      items: [
        Invoice(
          id: 'inv-1',
          invoiceNumber: 'INV-2026-089',
          patientName: 'Pooja Paid',
          serviceName: 'Cardiology Consultation',
          amount: 1000,
          gstRate: 18,
          gstAmount: 180,
          totalAmount: 1180,
          status: 'paid',
          createdAt: _today,
        ),
      ],
      hasMore: false,
    ),
  );

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(BillingRepository repository) => ProviderScope(
  overrides: [
    appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
    preferencesStoreProvider.overrideWithValue(FakePreferencesStore()),
    billingRepositoryProvider.overrideWithValue(repository),
    featureAccessProvider.overrideWithValue(
      FeatureAccessSnapshot([
        const FeatureAccess(
          key: FeatureKey.billingInvoices,
          effectiveEnabled: true,
          includedByPlan: true,
        ),
      ]),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: BillingScreen()),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 2400);
  addTearDown(tester.view.reset);
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool warnIfMissed = true,
}) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: warnIfMissed);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('skeleton instead of spinners while loading', (tester) async {
    _phone(tester);
    final gate = Completer<void>();
    await tester.pumpWidget(_app(_FakeRepository(gate: gate)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Pooja Paid'), findsOneWidget);
  });

  testWidgets('glance grid, status tabs, derived overdue and reminders', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository()));
    await tester.pumpAndSettle();

    // Executive glance grid from the existing summary.
    expect(find.text('COLLECTED THIS MONTH'), findsOneWidget);
    expect(find.text('₹48,250'), findsOneWidget);
    expect(find.text('Awaiting payment'), findsOneWidget);

    // Every status renders; yesterday's pending payment reads as Overdue.
    expect(find.text('Omar Overdue'), findsOneWidget);
    expect(find.text('Overdue'), findsWidgets); // badge + tab
    // Reminders only on unpaid cards: 2 pending + 1 pay-at-clinic.
    expect(find.text('Send Reminder'), findsNWidgets(3));
    expect(find.text('5 transactions'), findsOneWidget);

    // Overdue tab: server loads pending, device narrows to past-dated.
    // The tab precedes the cards' Overdue badges in the tree.
    await _tap(tester, find.text('Overdue').first);
    expect(find.text('Omar Overdue'), findsOneWidget);
    expect(find.text('Priya Pending'), findsNothing);
    expect(find.text('1 overdue of 2 loaded'), findsOneWidget);

    // A summary tile jumps to its filter.
    // Tappable tiles lay their ink layer over the text, so the tap lands on
    // the tile (intended) rather than the label itself.
    await _tap(tester, find.text('Refunded').first, warnIfMissed: false);
    expect(find.text('Ravi Refund'), findsOneWidget);
    expect(find.text('Pooja Paid'), findsNothing);
    expect(find.text('Send Reminder'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches to invoices with 3-tier invoice cards', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository()));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Invoices'));
    expect(find.text('#INV-2026-089'), findsOneWidget);
    expect(find.text('₹1,180'), findsOneWidget);
    expect(find.text('View Breakdown'), findsOneWidget);
    expect(find.byTooltip('Share invoice PDF'), findsOneWidget);
    expect(find.text('Search invoice #, patient or service'), findsOneWidget);
  });

  testWidgets('empty state resets filters to all dates', (tester) async {
    _phone(tester);
    final repository = _FakeRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    // Step to next month: nothing there.
    await _tap(tester, find.byTooltip('Next month'));
    expect(find.text('No Transactions Found'), findsOneWidget);
    await _tap(tester, find.text('Reset filters'));
    expect(repository.queries.last.startDate, isNull);
    expect(repository.queries.last.endDateExclusive, isNull);
    expect(find.text('All dates'), findsOneWidget);
    expect(find.text('Pooja Paid'), findsOneWidget);
  });
}
