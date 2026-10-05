import 'dart:async';

import 'package:doctylia_app/app/app.dart';
import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/core/data/app_data_source.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/core/storage/preferences_store.dart';
import 'package:doctylia_app/core/widgets/skeleton.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:doctylia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_stats_grid.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/revenue_website_cards.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/today_schedule_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_preferences_store.dart';

/// Holds the dashboard load open until the test completes it.
final class _HeldRepository implements DashboardRepository {
  final completer = Completer<Result<DashboardSnapshot>>();

  @override
  Future<Result<DashboardSnapshot>> loadDashboard(String doctorId) =>
      completer.future;

  @override
  Stream<void> watchDashboardChanges(String doctorId) => const Stream.empty();
}

DashboardSnapshot _loaded() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DashboardSnapshot(
    stats: const DashboardStats(
      appointments: 7,
      patients: 5,
      totalRevenue: 1234567,
      todayAppointments: 2,
      reviewCount: 3,
      averageRating: 4.2,
      revenueGrowthPercent: -3.1,
    ),
    todaySchedule: [
      for (var i = 0; i < 2; i++)
        DashboardAppointment(
          id: 'r$i',
          patientName: 'Ananya Sharma',
          serviceName: 'Follow-up',
          appointmentType: 'Online',
          scheduledAt: today.add(Duration(hours: 15 + i)),
          status: DashboardAppointmentStatus.pending,
          timeSlot: '15:00',
        ),
    ],
    revenueSeries: [
      for (var i = 0; i < 30; i++)
        RevenuePoint(
          day: today.subtract(Duration(days: 29 - i)),
          amount: i * 50.0,
        ),
    ],
    monthlyRevenue: 3500,
    websiteIsLive: false,
    websiteSlug: 'dr-ananya',
    appointmentsUsed: 0,
    appointmentsCap: null,
  );
}

Map<Type, Rect> _sectionRects(WidgetTester tester) => {
  for (final type in [
    DashboardHeader,
    DashboardStatsGrid,
    TodayScheduleCard,
    RevenueCard,
    WebsiteShareCard,
  ])
    type: tester.getRect(find.byType(type)),
};

void main() {
  testWidgets('skeleton mirrors the loaded dashboard with no layout shift', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1900);
    addTearDown(tester.view.reset);
    final repository = _HeldRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataSourceProvider.overrideWithValue(const AppDataSource.mock()),
          preferencesStoreProvider.overrideWithValue(
            FakePreferencesStore({
              'has_seen_onboarding': true,
              'mock_doctor_session': true,
              'mock_doctor_email': 'doctor@gmail.com',
            }),
          ),
          dashboardRepositoryProvider.overrideWithValue(repository),
        ],
        child: const DoctyliaApp(),
      ),
    );
    // The skeleton pulses forever, so pump frames instead of settling.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final skeleton = _sectionRects(tester);

    repository.completer.complete(Success(_loaded()));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(Skeleton), findsNothing);
    expect(tester.takeException(), isNull);
    final loaded = _sectionRects(tester);

    for (final type in skeleton.keys) {
      expect(
        loaded[type]!.top,
        closeTo(skeleton[type]!.top, 0.5),
        reason: '$type moved',
      );
      expect(
        loaded[type]!.height,
        closeTo(skeleton[type]!.height, 0.5),
        reason: '$type resized',
      );
    }
  });
}
