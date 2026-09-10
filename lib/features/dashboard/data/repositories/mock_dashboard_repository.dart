import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/domain/repositories/dashboard_repository.dart';

final class MockDashboardRepository implements DashboardRepository {
  const MockDashboardRepository();

  @override
  Future<Result<DashboardSnapshot>> loadDashboard(String doctorId) {
    return RepositoryGuard.run(() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final revenue = List.generate(30, (index) {
        final day = today.subtract(Duration(days: 29 - index));
        final base = [1800, 2400, 0, 3200, 4100, 2800, 5200][index % 7];
        return RevenuePoint(day: day, amount: base.toDouble());
      });

      return DashboardSnapshot(
        stats: const DashboardStats(
          appointments: 124,
          patients: 86,
          totalRevenue: 248500,
          todayAppointments: 4,
          reviewCount: 37,
          averageRating: 4.8,
          monthlyPaidInvoices: 24,
          revenueGrowthPercent: 12.4,
          newPatientsThisWeek: 4,
          activePatientsThisWeek: 13,
        ),
        todaySchedule: [
          DashboardAppointment(
            id: 'appt-1',
            patientName: 'Ananya Sharma',
            serviceName: 'General Consultation',
            appointmentType: 'In-clinic',
            scheduledAt: today.add(const Duration(hours: 9, minutes: 30)),
            status: DashboardAppointmentStatus.confirmed,
          ),
          DashboardAppointment(
            id: 'appt-2',
            patientName: 'Rohan Mehta',
            serviceName: 'Follow-up Consultation',
            appointmentType: 'Online',
            scheduledAt: today.add(const Duration(hours: 11)),
            status: DashboardAppointmentStatus.pending,
          ),
          DashboardAppointment(
            id: 'appt-4',
            patientName: 'Kabir Singh',
            serviceName: 'General Consultation',
            appointmentType: 'In-clinic',
            scheduledAt: today.add(const Duration(hours: 16, minutes: 30)),
            status: DashboardAppointmentStatus.confirmed,
          ),
        ],
        revenueSeries: revenue,
        monthlyRevenue: revenue.fold(0, (sum, point) => sum + point.amount),
        websiteIsLive: true,
        websiteSlug: 'doctor',
        appointmentsUsed: 24,
        appointmentsCap: null,
      );
    });
  }

  @override
  Stream<void> watchDashboardChanges(String doctorId) => const Stream.empty();
}
