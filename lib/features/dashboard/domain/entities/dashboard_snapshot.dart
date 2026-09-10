import 'package:doctylia_app/shared/entitlements/plan_status.dart';

enum DashboardAppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled,
  noShow,
}

class DashboardAppointment {
  const DashboardAppointment({
    required this.id,
    required this.patientName,
    required this.serviceName,
    required this.appointmentType,
    required this.scheduledAt,
    required this.status,
    this.timeSlot,
  });

  final String id;
  final String patientName;
  final String serviceName;
  final String appointmentType;
  final DateTime scheduledAt;
  final DashboardAppointmentStatus status;
  final String? timeSlot;
}

class RevenuePoint {
  const RevenuePoint({required this.day, required this.amount});

  final DateTime day;
  final double amount;
}

class DashboardStats {
  const DashboardStats({
    required this.appointments,
    required this.patients,
    required this.totalRevenue,
    required this.todayAppointments,
    this.weekRevenue = 0,
    this.lastWeekAppointments = 0,
    this.reviewCount = 0,
    this.averageRating = 0,
    this.monthlyPaidInvoices = 0,
    this.revenueGrowthPercent,
    this.newPatientsThisWeek = 0,
    this.activePatientsThisWeek = 0,
  });

  final int appointments;
  final int patients;
  final double totalRevenue;
  final int todayAppointments;
  final double weekRevenue;
  final int lastWeekAppointments;
  final int reviewCount;
  final double averageRating;
  final int monthlyPaidInvoices;
  final double? revenueGrowthPercent;
  final int newPatientsThisWeek;
  final int activePatientsThisWeek;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.stats,
    required this.todaySchedule,
    required this.revenueSeries,
    required this.monthlyRevenue,
    required this.websiteIsLive,
    required this.websiteSlug,
    required this.appointmentsUsed,
    required this.appointmentsCap,
    this.isPremium = false,
    this.planStatus,
    this.trialEnd,
    this.maintenanceMode = false,
  });

  final DashboardStats stats;
  final List<DashboardAppointment> todaySchedule;
  final List<RevenuePoint> revenueSeries;
  final double monthlyRevenue;
  final bool websiteIsLive;
  final String? websiteSlug;
  final int appointmentsUsed;
  final int? appointmentsCap;
  final bool isPremium;
  final PlanStatus? planStatus;
  final DateTime? trialEnd;
  final bool maintenanceMode;

  bool get isNearAppointmentCap {
    final cap = appointmentsCap;
    return !isPremium &&
        cap != null &&
        cap > 0 &&
        appointmentsUsed / cap >= 0.9;
  }

  bool get hasNoPracticeData =>
      stats.appointments == 0 && stats.patients == 0 && stats.totalRevenue == 0;
}
