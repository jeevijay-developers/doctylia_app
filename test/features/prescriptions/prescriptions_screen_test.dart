import 'dart:async';

import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/core/theme/app_theme.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/prescriptions/data/repositories/mock_prescription_repository.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription_status.dart';
import 'package:doctylia_app/features/prescriptions/domain/repositories/prescription_repository.dart';
import 'package:doctylia_app/features/prescriptions/presentation/providers/prescription_providers.dart';
import 'package:doctylia_app/features/prescriptions/presentation/screens/prescriptions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_preferences_store.dart';

final _today = DateUtils.dateOnly(DateTime.now());

Prescription _rx(
  String id,
  String name, {
  required DateTime date,
  DateTime? followUp,
}) => Prescription(
  id: id,
  patientName: name,
  date: date,
  followUpDate: followUp,
  patientAge: 34,
  patientWeight: 68,
  diagnosis: 'Acute bronchitis',
  medicines: const [
    MedicineItem(
      name: 'Amoxicillin',
      strength: '500mg',
      morning: true,
      evening: true,
      durationDays: 5,
    ),
  ],
);

/// One prescription per derived status.
final _items = [
  _rx('a', 'Asha Active', date: _today),
  _rx(
    'f',
    'Farhan Followup',
    date: _today.subtract(const Duration(days: 20)),
    followUp: _today.add(const Duration(days: 1)),
  ),
  _rx('c', 'Chitra Completed', date: _today.subtract(const Duration(days: 30))),
];

/// Serves [_items] for any query; [gate] holds the first list load open.
final class _FakeRepository implements PrescriptionRepository {
  _FakeRepository({this.gate});

  final Completer<void>? gate;

  @override
  Future<Result<PageResult<Prescription>>> list(
    PageRequest page, {
    String search = '',
    DateTime? date,
  }) async {
    await gate?.future;
    return Success(
      PageResult(items: _items, hasMore: false, totalCount: _items.length),
    );
  }

  @override
  Future<Result<PrescriptionSummary>> summary({required DateTime now}) =>
      RepositoryGuard.run(
        () => const PrescriptionSummary(
          active: 1,
          followUpsDue: 1,
          issuedThisWeek: 4,
        ),
      );

  @override
  Future<Result<List<PrescriptionPatient>>> listPatients() async =>
      const Success([]);

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Stream<void> watchPatientChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(PrescriptionRepository repository) => ProviderScope(
  overrides: [
    appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
    preferencesStoreProvider.overrideWithValue(FakePreferencesStore()),
    prescriptionRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const PrescriptionsScreen()),
);

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(375, 1600);
  addTearDown(tester.view.reset);
}

void main() {
  group('prescriptionStatusOf', () {
    final now = DateTime(2026, 10, 23, 15);

    Prescription at(DateTime date, [DateTime? followUp]) =>
        _rx('x', 'P', date: date, followUp: followUp);

    test('issued today is active; earlier with no follow-up is completed', () {
      expect(
        prescriptionStatusOf(at(DateTime(2026, 10, 23)), now: now),
        PrescriptionStatus.active,
      );
      expect(
        prescriptionStatusOf(at(DateTime(2026, 10, 1)), now: now),
        PrescriptionStatus.completed,
      );
    });

    test('follow-up window edges', () {
      final issued = DateTime(2026, 9, 1);
      PrescriptionStatus withFollowUp(DateTime f) =>
          prescriptionStatusOf(at(issued, f), now: now);
      // 3 days ahead → due; 4 days ahead → still an upcoming (active) course.
      expect(
        withFollowUp(DateTime(2026, 10, 26)),
        PrescriptionStatus.followUpDue,
      );
      expect(withFollowUp(DateTime(2026, 10, 27)), PrescriptionStatus.active);
      // Missed up to 14 days ago → due; older → completed.
      expect(
        withFollowUp(DateTime(2026, 10, 9)),
        PrescriptionStatus.followUpDue,
      );
      expect(withFollowUp(DateTime(2026, 10, 8)), PrescriptionStatus.completed);
    });

    test('week starts Monday', () {
      expect(startOfWeek(DateTime(2026, 10, 23)), DateTime(2026, 10, 19));
      expect(startOfWeek(DateTime(2026, 10, 19, 8)), DateTime(2026, 10, 19));
    });
  });

  test('mock summary agrees with the status rule', () async {
    final now = DateTime.now();
    final repository = MockPrescriptionRepository();
    final summary = (await repository.summary(now: now)) as Success;
    final page =
        (await repository.list(const PageRequest(limit: 100))) as Success;
    final items = (page.value as PageResult<Prescription>).items;
    final value = summary.value as PrescriptionSummary;
    expect(
      value.active,
      items
          .where(
            (p) =>
                prescriptionStatusOf(p, now: now) == PrescriptionStatus.active,
          )
          .length,
    );
  });

  testWidgets('shows a skeleton, not a spinner, while loading', (tester) async {
    _phone(tester);
    final gate = Completer<void>();
    await tester.pumpWidget(_app(_FakeRepository(gate: gate)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Skeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Asha Active'), findsOneWidget);
  });

  testWidgets('3-tier cards, metrics and status tabs on a phone', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository()));
    await tester.pumpAndSettle();

    // Header, metric strip, tabs.
    expect(find.text('New Prescription'), findsOneWidget);
    expect(find.text('1 active Rx'), findsOneWidget);
    expect(find.text('Issued this week'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Active / Ongoing'), findsOneWidget);

    // Card tiers: meta, status badges, medication chips, actions.
    expect(find.text('34 yrs · 68 kg'), findsNWidgets(3));
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Follow-up due'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets); // badge + tab label
    expect(find.text('1-0-1'), findsNWidgets(3));
    expect(find.text('5 days'), findsNWidgets(3));
    expect(find.text('View Details'), findsNWidgets(3));

    // Tabs filter the loaded results by derived status.
    // The 4th tab sits past the right edge at phone width; the strip scrolls.
    await tester.ensureVisible(find.text('Follow-up Due'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Follow-up Due'));
    await tester.pumpAndSettle();
    expect(find.text('Farhan Followup'), findsOneWidget);
    expect(find.text('Asha Active'), findsNothing);
    expect(find.text('1 of 3 loaded'), findsOneWidget);

    await tester.ensureVisible(find.text('Active / Ongoing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active / Ongoing'));
    await tester.pumpAndSettle();
    expect(find.text('Asha Active'), findsOneWidget);
    expect(find.text('Chitra Completed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Renew opens the form prefilled as a new prescription', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(_FakeRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renew').first);
    await tester.pumpAndSettle();
    expect(find.text('Renew Prescription'), findsOneWidget);
    expect(find.text('Acute bronchitis'), findsWidgets);
  });
}
