import 'package:doctylia_app/app/router/route_names.dart';
import 'package:flutter/material.dart';

class DashboardDestination {
  const DashboardDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

const dashboardDestinations = [
  DashboardDestination(
    label: 'Home',
    path: RoutePaths.dashboard,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  ),
  DashboardDestination(
    label: 'Appointments',
    path: RoutePaths.appointments,
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
  ),
  DashboardDestination(
    label: 'Patients',
    path: RoutePaths.patients,
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
  ),
  DashboardDestination(
    label: 'More',
    path: RoutePaths.more,
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  ),
];

int dashboardDestinationIndex(String location) {
  if (location.startsWith(RoutePaths.appointments)) return 1;
  if (location.startsWith(RoutePaths.patients)) return 2;
  if (location == RoutePaths.dashboard) return 0;
  return 3;
}

String dashboardPageTitle(String location) {
  if (location.startsWith('${RoutePaths.patients}/')) {
    return 'Medical Record';
  }

  return const {
        RoutePaths.dashboard: 'Dashboard',
        RoutePaths.appointments: 'Appointments',
        RoutePaths.patients: 'Patients',
        RoutePaths.more: 'More',
        RoutePaths.prescriptions: 'Prescriptions',
        RoutePaths.billing: 'Billing',
        RoutePaths.myWebsite: 'My Website',
        RoutePaths.blog: 'Blog',
        RoutePaths.reviews: 'Reviews',
        RoutePaths.inquiries: 'Inquiries',
        RoutePaths.staff: 'Staff Management',
        RoutePaths.settings: 'Settings',
        RoutePaths.support: 'Contact Support',
      }[location] ??
      'Doctylia';
}
