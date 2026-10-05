import 'package:doctylia_app/app/router/route_names.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_form_sheet.dart';
import 'package:doctylia_app/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

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
    return DashboardShadcnScope(
      child: DashboardSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const DashboardIconTile(
                  icon: Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Schedule",
                        style: TextStyle(
                          color: AppColors.onSurface(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        DateFormat('EEEE, MMM d').format(today),
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                shadcn.GhostButton(
                  onPressed: () => context.go(RoutePaths.appointments),
                  size: shadcn.ButtonSize.small,
                  trailing: const Icon(Icons.chevron_right_rounded, size: 15),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            shadcn.Divider(color: DashboardTokens.border(context)),
            if (appointments.isEmpty)
              _CompletedScheduleState(
                hadAppointments: totalTodayCount > 0,
                onAddWalkIn: () =>
                    showAppointmentForm(context, ref, walkIn: true),
                onCheckTomorrow: () => _checkTomorrow(context, ref),
              )
            else ...[
              const SizedBox(height: 12),
              for (var index = 0; index < appointments.length; index++)
                AppointmentRow(
                  appointment: appointments[index],
                  isLast: index == appointments.length - 1,
                ),
              const SizedBox(height: 12),
              _ScheduleActions(
                onAddWalkIn: () =>
                    showAppointmentForm(context, ref, walkIn: true),
                onCheckTomorrow: () => _checkTomorrow(context, ref),
              ),
            ],
          ],
        ),
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
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 0),
    child: Column(
      children: [
        const _ScheduleCompleteMark(),
        const SizedBox(height: 14),
        Text(
          hadAppointments
              ? 'All appointments wrapped up for today!'
              : 'No appointments scheduled for today',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your schedule is currently clear. New bookings and walk-in '
          'consultations will appear here automatically.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.mutedText(context),
            fontSize: 11,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
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
    width: 64,
    height: 64,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.14),
                DashboardTokens.teal.withValues(alpha: 0.1),
              ],
            ),
          ),
          padding: const EdgeInsets.all(11),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
        ),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface(context), width: 3),
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
        child: shadcn.PrimaryButton(
          onPressed: onAddWalkIn,
          leading: const Icon(Icons.add_rounded, size: 16),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Add Walk-in', maxLines: 1),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: shadcn.OutlineButton(
          onPressed: onCheckTomorrow,
          leading: const Icon(Icons.event_outlined, size: 15),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Check Tomorrow', maxLines: 1),
          ),
        ),
      ),
    ],
  );
}

class AppointmentRow extends StatelessWidget {
  const AppointmentRow({
    required this.appointment,
    this.isLast = true,
    super.key,
  });

  final DashboardAppointment appointment;

  /// Hides the timeline connector below the last row.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(appointment.status);
    final hasTime = appointment.timeSlot != null;
    final name = appointment.patientName;
    return DashboardShadcnScope(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 50,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hasTime
                          ? DateFormat('h:mm').format(appointment.scheduledAt)
                          : '—',
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.onSurface(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      hasTime
                          ? DateFormat('a').format(appointment.scheduledAt)
                          : 'Time not set',
                      maxLines: 2,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: AppColors.subtleText(context),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.25),
                        width: 3,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.only(top: 6),
                        color: DashboardTokens.border(context),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface(
                      context,
                    ).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(
                      DashboardTokens.innerRadius,
                    ),
                    border: Border.all(color: DashboardTokens.border(context)),
                  ),
                  child: Row(
                    children: [
                      shadcn.Avatar(
                        initials: name.trim().isEmpty
                            ? 'P'
                            : shadcn.Avatar.getInitials(name),
                        size: 36,
                        borderRadius: 10,
                        backgroundColor: AppColors.isDark(context)
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : AppColors.primary50,
                        theme: shadcn.AvatarTheme(
                          textStyle: TextStyle(
                            color: AppColors.isDark(context)
                                ? AppColors.primary400
                                : AppColors.primary600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.onSurface(context),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${appointment.serviceName} · ${appointment.appointmentType}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.mutedText(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _StatusPill(status: appointment.status),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final DashboardAppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final label = status == DashboardAppointmentStatus.noShow
        ? 'No show'
        : '${status.name[0].toUpperCase()}${status.name.substring(1)}';
    return DashboardToneBadge(
      label: label,
      color: _statusColor(status),
      showDot: true,
    );
  }
}

Color _statusColor(DashboardAppointmentStatus status) => switch (status) {
  DashboardAppointmentStatus.confirmed => AppColors.primary,
  DashboardAppointmentStatus.completed => AppColors.success,
  DashboardAppointmentStatus.cancelled => AppColors.destructive,
  DashboardAppointmentStatus.pending => AppColors.warning,
  DashboardAppointmentStatus.noShow => AppColors.warning,
};
