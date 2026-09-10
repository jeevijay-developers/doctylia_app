import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/dashboard/data/repositories/mock_dashboard_repository.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns typed dashboard aggregates and a bounded today list', () async {
    final result = await const MockDashboardRepository().loadDashboard(
      'doctor-id',
    );
    expect(result, isA<Success<DashboardSnapshot>>());
    final dashboard = (result as Success<DashboardSnapshot>).value;

    expect(dashboard.stats.appointments, greaterThan(0));
    expect(dashboard.todaySchedule.length, lessThanOrEqualTo(6));
    expect(dashboard.revenueSeries.length, 30);
    expect(
      dashboard.monthlyRevenue,
      dashboard.revenueSeries.fold(0.0, (sum, point) => sum + point.amount),
    );
    expect(dashboard.websiteSlug, isNotNull);
  });

  test('near-cap warning begins at 90 percent for non-premium plans', () {
    DashboardSnapshot snapshot(int used) => DashboardSnapshot(
      stats: const DashboardStats(
        appointments: 0,
        patients: 0,
        totalRevenue: 0,
        todayAppointments: 0,
      ),
      todaySchedule: const [],
      revenueSeries: const [],
      monthlyRevenue: 0,
      websiteIsLive: false,
      websiteSlug: null,
      appointmentsUsed: used,
      appointmentsCap: 10,
    );
    expect(snapshot(8).isNearAppointmentCap, isFalse);
    expect(snapshot(9).isNearAppointmentCap, isTrue);
  });
}
