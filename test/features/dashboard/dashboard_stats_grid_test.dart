import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_stats_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders inside a vertically unbounded dashboard list', (
    tester,
  ) async {
    const snapshot = DashboardSnapshot(
      stats: DashboardStats(
        appointments: 12,
        patients: 8,
        totalRevenue: 4200,
        todayAppointments: 3,
        reviewCount: 9,
        averageRating: 4.7,
      ),
      todaySchedule: [],
      revenueSeries: [],
      monthlyRevenue: 0,
      websiteIsLive: false,
      websiteSlug: null,
      appointmentsUsed: 0,
      appointmentsCap: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [DashboardStatsGrid(snapshot: snapshot)],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('TOTAL PRACTICE REVENUE'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Practice Rating'), findsOneWidget);
    expect(find.text('9 verified patient reviews'), findsOneWidget);
    expect(find.text('4.7 \u2605'), findsOneWidget);
  });
}
