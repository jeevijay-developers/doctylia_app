import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_form_sheet.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TodayScheduleCard extends ConsumerWidget {
  const TodayScheduleCard({
    required this.appointments,
    this.totalTodayCount = 0,
    super.key,
  });

  final List<DashboardAppointment> appointments;
  final int totalTodayCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _SectionIcon(icon: Icons.calendar_today_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Schedule",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMM d').format(today),
                      style: TextStyle(
                        color: AppColors.subtleText(context),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go(RoutePaths.appointments),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 1),
                    Icon(Icons.chevron_right_rounded, size: 15),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Divider(height: 1, color: AppColors.border(context)),
          if (appointments.isEmpty)
            _CompletedScheduleState(
              hadAppointments: totalTodayCount > 0,
              onAddWalkIn: () =>
                  showAppointmentForm(context, ref, walkIn: true),
              onCheckTomorrow: () => _checkTomorrow(context, ref),
            )
          else ...[
            const SizedBox(height: 4),
            for (var index = 0; index < appointments.length; index++) ...[
              AppointmentRow(appointment: appointments[index]),
              if (index != appointments.length - 1)
                Divider(height: 1, color: AppColors.border(context)),
            ],
            const SizedBox(height: 8),
            _ScheduleActions(
              onAddWalkIn: () =>
                  showAppointmentForm(context, ref, walkIn: true),
              onCheckTomorrow: () => _checkTomorrow(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _checkTomorrow(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    await ref
        .read(appointmentsProvider.notifier)
        .filterDates(tomorrow, tomorrow);
    if (context.mounted) context.go(RoutePaths.appointments);
  }
}

class _CompletedScheduleState extends StatelessWidget {
  const _CompletedScheduleState({
    required this.hadAppointments,
    required this.onAddWalkIn,
    required this.onCheckTomorrow,
  });

  final bool hadAppointments;
  final VoidCallback onAddWalkIn;
  final VoidCallback onCheckTomorrow;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(5, 17, 5, 2),
    child: Column(
      children: [
        const _ScheduleCompleteMark(),
        const SizedBox(height: 13),
        Text(
          hadAppointments
              ? 'All appointments wrapped up for today!'
              : 'No appointments scheduled for today',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your schedule is currently clear. New bookings\n'
          'and walk-in consultations will appear here\n'
          'automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.mutedText(context),
            fontSize: 10,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _ScheduleActions(
          onAddWalkIn: onAddWalkIn,
          onCheckTomorrow: onCheckTomorrow,
        ),
      ],
    ),
  );
}

class _ScheduleCompleteMark extends StatelessWidget {
  const _ScheduleCompleteMark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 62,
    height: 62,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
        ),
        Positioned(
          right: -3,
          top: -5,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface(context), width: 3),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScheduleActions extends StatelessWidget {
  const _ScheduleActions({
    required this.onAddWalkIn,
    required this.onCheckTomorrow,
  });

  final VoidCallback onAddWalkIn;
  final VoidCallback onCheckTomorrow;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton.icon(
          onPressed: onAddWalkIn,
          style: FilledButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            foregroundColor: AppColors.isDark(context)
                ? AppColors.primary400
                : AppColors.primary600,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text(
            'Add Walk-in',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: onCheckTomorrow,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.onSurface(context),
            padding: const EdgeInsets.symmetric(vertical: 9),
            side: BorderSide(color: AppColors.border(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          icon: const Icon(Icons.calendar_today_outlined, size: 13),
          label: const Text(
            'Check\nTomorrow',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );
}

class AppointmentRow extends StatelessWidget {
  const AppointmentRow({required this.appointment, super.key});

  final DashboardAppointment appointment;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary50,
          foregroundColor: AppColors.primary600,
          child: Text(
            appointment.patientName.isEmpty ? 'P' : appointment.patientName[0],
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.patientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${appointment.serviceName} \u00B7 ${appointment.appointmentType}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.mutedText(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              appointment.timeSlot == null
                  ? 'Time not set'
                  : DateFormat('h:mm a').format(appointment.scheduledAt),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            _StatusPill(status: appointment.status),
          ],
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final DashboardAppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final label = status == DashboardAppointmentStatus.noShow
        ? 'No show'
        : '${status.name[0].toUpperCase()}${status.name.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(DashboardAppointmentStatus status) => switch (status) {
    DashboardAppointmentStatus.confirmed => AppColors.primary,
    DashboardAppointmentStatus.completed => AppColors.success,
    DashboardAppointmentStatus.cancelled => AppColors.destructive,
    DashboardAppointmentStatus.pending => AppColors.warning,
    DashboardAppointmentStatus.noShow => AppColors.warning,
  };
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border(context)),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadow(context, alpha: 0.055),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.075),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Icon(icon, size: 17, color: AppColors.primary),
  );
}
