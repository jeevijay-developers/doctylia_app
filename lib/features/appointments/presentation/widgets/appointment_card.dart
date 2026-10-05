import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_form_sheet.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_ui.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_gate.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

String _initials(String name) =>
    name.trim().isEmpty ? 'P' : shadcn.Avatar.getInitials(name);

/// Statuses that can still be rescheduled or cancelled from the card.
const _actionableStatuses = {
  AppointmentStatus.pending,
  AppointmentStatus.confirmed,
};

/// Three-tier appointment card: identity header, recessed metadata grid and
/// an actions footer.
class AppointmentCard extends ConsumerStatefulWidget {
  const AppointmentCard({
    required this.appointment,
    this.selectionMode = false,
    this.selected = false,
    this.onSelected,
    super.key,
  });
  final Appointment appointment;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  ConsumerState<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends ConsumerState<AppointmentCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final writeDisabled =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    final color = appointmentStatusColor(appointment.status);
    final canAct =
        !writeDisabled && _actionableStatuses.contains(appointment.status);
    final selectedForBulk = widget.selectionMode && widget.selected;
    return DashboardShadcnScope(
      child: shadcn.Card(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(DashboardTokens.radius),
        borderColor: selectedForBulk
            ? DashboardTokens.teal.withValues(alpha: 0.6)
            : DashboardTokens.border(context),
        boxShadow: DashboardTokens.shadow(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header + body form the tap target; the footer buttons sit
            // outside it so they stay independently tappable.
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.selectionMode
                    ? widget.onSelected
                    : () => showAppointmentDetails(context, appointment),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CardHeader(
                        appointment: appointment,
                        color: color,
                        selectionMode: widget.selectionMode,
                        selected: widget.selected,
                        onSelected: widget.onSelected,
                      ),
                      const SizedBox(height: 12),
                      _MetadataGrid(appointment: appointment),
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.selectionMode) ...[
              shadcn.Divider(color: DashboardTokens.border(context)),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
                child: _busy
                    ? const Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DashboardTokens.teal,
                            ),
                          ),
                        ),
                      )
                    : Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (canAct) ...[
                            shadcn.GhostButton(
                              onPressed: _cancel,
                              size: shadcn.ButtonSize.small,
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppColors.destructive,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            shadcn.OutlineButton(
                              onPressed: _reschedule,
                              size: shadcn.ButtonSize.small,
                              leading: const Icon(
                                Icons.event_repeat_rounded,
                                size: 14,
                              ),
                              child: const Text('Reschedule'),
                            ),
                          ],
                          shadcn.PrimaryButton(
                            onPressed: () =>
                                showAppointmentDetails(context, appointment),
                            size: shadcn.ButtonSize.small,
                            trailing: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                            ),
                            child: const Text('View Details'),
                          ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Picks a new slot (date only for walk-ins) and applies it through the
  /// controller's existing `reschedule` call.
  Future<void> _reschedule() async {
    final appointment = widget.appointment;
    final now = DateTime.now();
    final initial = appointment.scheduledAt.isBefore(now)
        ? now
        : appointment.scheduledAt;
    final date = await showDatePicker(
      context: context,
      helpText: 'Reschedule appointment',
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    var next = DateTime(date.year, date.month, date.day);
    if (!appointment.isWalkIn) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !mounted) return;
      next = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }
    await _run(
      () => ref
          .read(appointmentsProvider.notifier)
          .reschedule(appointment.id, next),
      'Appointment rescheduled',
    );
  }

  /// Confirms, then marks the appointment cancelled via `updateStatus`.
  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: const Text('Cancel appointment?'),
        content: Text(
          "${widget.appointment.patientName}'s appointment will be marked as "
          'cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;
    await _run(
      () => ref
          .read(appointmentsProvider.notifier)
          .updateStatus(widget.appointment.id, AppointmentStatus.cancelled),
      'Appointment cancelled',
    );
  }

  Future<void> _run(
    Future<String?> Function() operation,
    String success,
  ) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final error = await operation();
    if (mounted) setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(error ?? success)));
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.appointment,
    required this.color,
    required this.selectionMode,
    required this.selected,
    required this.onSelected,
  });

  final Appointment appointment;
  final Color color;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final token = appointment.tokenNumber?.trim();
    final subtitle = [
      appointment.serviceName,
      if (token != null && token.isNotEmpty) 'Token $token',
    ].join(' · ');
    return Row(
      children: [
        if (selectionMode) ...[
          shadcn.Checkbox(
            state: selected
                ? shadcn.CheckboxState.checked
                : shadcn.CheckboxState.unchecked,
            activeColor: DashboardTokens.teal,
            onChanged: (_) => onSelected?.call(),
          ),
          const SizedBox(width: 10),
        ],
        shadcn.Avatar(
          initials: _initials(appointment.patientName),
          size: 44,
          borderRadius: 13,
          backgroundColor: color.withValues(alpha: 0.12),
          theme: shadcn.AvatarTheme(
            textStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          badge: shadcn.AvatarBadge(size: 11, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.patientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedText(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        DashboardToneBadge(
          label: appointmentStatusLabel(appointment.status),
          color: color,
          showDot: true,
        ),
      ],
    );
  }
}

/// Recessed 3-column grid: schedule, visit mode and fee.
class _MetadataGrid extends StatelessWidget {
  const _MetadataGrid({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final isOnline = appointment.type == AppointmentType.online;
    final paymentColor = appointmentPaymentColor(appointment.paymentStatus);
    Widget divider() => Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: DashboardTokens.border(context),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
        border: Border.all(
          color: DashboardTokens.border(context).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetaCell(
              icon: Icons.calendar_today_rounded,
              label: 'Schedule',
              value: DateFormat('EEE, d MMM').format(appointment.scheduledAt),
              detail: appointment.isWalkIn
                  ? 'Walk-in'
                  : DateFormat('h:mm a').format(appointment.scheduledAt),
              detailIcon: appointment.isWalkIn
                  ? Icons.directions_walk_rounded
                  : Icons.schedule_rounded,
            ),
          ),
          divider(),
          Expanded(
            child: _MetaCell(
              icon: isOnline
                  ? Icons.videocam_rounded
                  : Icons.local_hospital_rounded,
              iconColor: isOnline ? DashboardTokens.teal : AppColors.primary,
              label: 'Mode',
              value: isOnline ? 'Video' : 'In-clinic',
              detail: isOnline ? 'Online' : 'Clinic visit',
            ),
          ),
          divider(),
          Expanded(
            child: _MetaCell(
              icon: Icons.currency_rupee_rounded,
              label: 'Fee',
              value: '₹${appointment.amount.toStringAsFixed(0)}',
              detail: appointmentPaymentLabel(appointment.paymentStatus),
              detailColor: paymentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.iconColor,
    this.detailIcon,
    this.detailColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color? iconColor;
  final IconData? detailIcon;
  final Color? detailColor;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: iconColor ?? DashboardTokens.tealDeep),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.subtleText(context),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 1),
        Row(
          children: [
            if (detailIcon != null) ...[
              Icon(detailIcon, size: 11, color: muted),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: detailColor ?? muted,
                  fontSize: 11,
                  fontWeight: detailColor == null
                      ? FontWeight.w500
                      : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> showAppointmentDetails(
  BuildContext context,
  Appointment appointment,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: appointmentSheetConstraints(context),
  shape: appointmentSheetShape,
  clipBehavior: Clip.antiAlias,
  builder: (_) => DashboardShadcnScope(
    child: _AppointmentDetails(appointment: appointment),
  ),
);

class _AppointmentDetails extends ConsumerStatefulWidget {
  const _AppointmentDetails({required this.appointment});
  final Appointment appointment;

  @override
  ConsumerState<_AppointmentDetails> createState() =>
      _AppointmentDetailsState();
}

class _AppointmentDetailsState extends ConsumerState<_AppointmentDetails> {
  bool _changing = false;

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final writeDisabled =
        ref.watch(trialStatusProvider).accessLevel == TrialAccessLevel.grace;
    final color = appointmentStatusColor(appointment.status);
    final locked = writeDisabled || _changing;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pinned handle + close button so the sheet is always dismissible.
            const SizedBox(
              height: 44,
              child: Stack(
                children: [
                  Align(alignment: Alignment.topCenter, child: SheetHandle()),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: AppSpacing.xs),
                      child: SheetCloseButton(),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        shadcn.Avatar(
                          initials: _initials(appointment.patientName),
                          size: 52,
                          borderRadius: 15,
                          backgroundColor: color.withValues(alpha: 0.12),
                          theme: shadcn.AvatarTheme(
                            textStyle: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointment.patientName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${appointment.serviceName} · ${appointment.type.name}',
                                style: TextStyle(
                                  color: AppColors.mutedText(context),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface(
                          context,
                        ).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(
                          DashboardTokens.radius,
                        ),
                        border: Border.all(
                          color: DashboardTokens.border(context),
                        ),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.phone_rounded,
                            text: appointment.patientPhone,
                          ),
                          _InfoRow(
                            icon: Icons.event_rounded,
                            text: appointment.isWalkIn
                                ? '${DateFormat('EEEE, d MMMM yyyy').format(appointment.scheduledAt)} · Walk-in'
                                : DateFormat(
                                    'EEEE, d MMMM yyyy · h:mm a',
                                  ).format(appointment.scheduledAt),
                          ),
                          _InfoRow(
                            icon: Icons.currency_rupee_rounded,
                            text: '₹${appointment.amount.toStringAsFixed(0)}',
                          ),
                          if (appointment.chiefComplaint?.isNotEmpty ?? false)
                            _InfoRow(
                              icon: Icons.sick_rounded,
                              text: 'Complaint: ${appointment.chiefComplaint}',
                            ),
                          if (appointment.notes?.isNotEmpty ?? false)
                            _InfoRow(
                              icon: Icons.sticky_note_2_rounded,
                              text: 'Notes: ${appointment.notes}',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppointmentSectionLabel('Status'),
                    ChoicePills<AppointmentStatus>(
                      options: const [
                        AppointmentStatus.pending,
                        AppointmentStatus.confirmed,
                        AppointmentStatus.completed,
                        AppointmentStatus.cancelled,
                        AppointmentStatus.noShow,
                      ],
                      value: appointment.status,
                      labelOf: appointmentStatusLabel,
                      colorOf: appointmentStatusColor,
                      onChanged: locked ? null : _changeStatus,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppointmentSectionLabel('Payment status'),
                    ChoicePills<AppointmentPaymentStatus>(
                      options: AppointmentPaymentStatus.values,
                      value: appointment.paymentStatus,
                      labelOf: appointmentPaymentLabel,
                      colorOf: appointmentPaymentColor,
                      onChanged: locked ? null : _changePayment,
                    ),
                    if (_changing) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const shadcn.LinearProgressIndicator(
                        color: DashboardTokens.teal,
                        minHeight: 3,
                      ),
                    ],
                    if (appointment.type == AppointmentType.online) ...[
                      const SizedBox(height: AppSpacing.md),
                      FeatureGate(
                        feature: FeatureKey.onlineConsultation,
                        lockedChild: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(
                              DashboardTokens.radius,
                            ),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.16),
                            ),
                          ),
                          child: const Row(
                            children: [
                              DashboardIconTile(
                                icon: Icons.lock_outline_rounded,
                                color: AppColors.primary,
                                size: 36,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Online Consultation',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Upgrade to Premium to generate Zoom meetings.',
                                      style: TextStyle(fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: _ZoomAction(appointment: appointment),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    shadcn.Divider(color: DashboardTokens.border(context)),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: shadcn.OutlineButton(
                              alignment: Alignment.center,
                              onPressed: writeDisabled
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      showAppointmentForm(
                                        context,
                                        ref,
                                        appointment: appointment,
                                      );
                                    },
                              leading: const Icon(Icons.edit_rounded, size: 16),
                              child: const Text('Edit'),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Tooltip(
                          message: 'Delete appointment',
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                DashboardTokens.innerRadius,
                              ),
                              border: Border.all(
                                color: AppColors.destructive.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: shadcn.IconButton.ghost(
                              onPressed: writeDisabled ? null : _delete,
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                                color: AppColors.destructive.withValues(
                                  alpha: writeDisabled ? 0.4 : 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (writeDisabled) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            DashboardTokens.innerRadius,
                          ),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Upgrade to continue editing appointments.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(AppointmentStatus? next) async {
    if (next == null || next == widget.appointment.status) return;
    final currentIsFinal = {
      AppointmentStatus.completed,
      AppointmentStatus.noShow,
      AppointmentStatus.cancelled,
    }.contains(widget.appointment.status);
    if (currentIsFinal) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          title: const Text('Correct final status?'),
          content: const Text(
            'An invoice already generated for a completed appointment will remain unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep current'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Change status'),
            ),
          ],
        ),
      );
      if (!(confirmed ?? false)) return;
    }
    await _runMutation(
      () => ref
          .read(appointmentsProvider.notifier)
          .updateStatus(widget.appointment.id, next),
      'Status updated',
    );
  }

  Future<void> _changePayment(AppointmentPaymentStatus? next) async {
    if (next == null || next == widget.appointment.paymentStatus) return;
    await _runMutation(
      () => ref
          .read(appointmentsProvider.notifier)
          .updatePaymentStatus(widget.appointment.id, next),
      'Payment status updated',
    );
  }

  Future<void> _runMutation(
    Future<String?> Function() operation,
    String success,
  ) async {
    setState(() => _changing = true);
    final error = await operation();
    if (!mounted) return;
    setState(() => _changing = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? success)));
    if (error == null) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: const Text('Delete appointment?'),
        content: const Text(
          'Historical invoices remain available after appointment deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await _runMutation(
      () =>
          ref.read(appointmentsProvider.notifier).delete(widget.appointment.id),
      'Appointment deleted',
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: DashboardTokens.tealDeep),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.onSurface(context),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ZoomAction extends ConsumerStatefulWidget {
  const _ZoomAction({required this.appointment});
  final Appointment appointment;

  @override
  ConsumerState<_ZoomAction> createState() => _ZoomActionState();
}

class _ZoomActionState extends ConsumerState<_ZoomAction> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final item = widget.appointment;
    final minutesUntil = item.scheduledAt.difference(DateTime.now()).inMinutes;
    final withinWindow = minutesUntil <= 15;
    final disabled =
        item.status == AppointmentStatus.cancelled ||
        item.status == AppointmentStatus.completed ||
        !withinWindow;
    final statusText = item.status == AppointmentStatus.cancelled
        ? 'Appointment cancelled'
        : item.status == AppointmentStatus.completed
        ? 'Consultation completed'
        : !withinWindow
        ? 'Opens 15 minutes before the appointment'
        : item.zoomJoinUrl == null
        ? 'Generate and start the meeting'
        : 'Ready to host';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DashboardTokens.teal.withValues(alpha: 0.1),
            DashboardTokens.teal.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(DashboardTokens.radius),
        border: Border.all(color: DashboardTokens.teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DashboardIconTile(
                icon: Icons.videocam_rounded,
                color: DashboardTokens.teal,
                size: 34,
              ),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(
                child: Text(
                  'Video Consultation · Zoom',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 12.5,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_error!, style: const TextStyle(color: AppColors.destructive)),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: DashboardTokens.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    DashboardTokens.innerRadius,
                  ),
                ),
              ),
              onPressed: disabled || _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(_error == null ? 'Start Meeting' : 'Retry'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(appointmentsProvider.notifier)
        .generateZoomMeeting(widget.appointment.id);
    if (!mounted) return;
    await result.fold(
      onSuccess: (links) async {
        final opened = await ref
            .read(externalLinkServiceProvider)
            .open(Uri.parse(links.startUrl));
        if (!opened) {
          setState(() => _error = 'Could not open the Zoom meeting.');
        }
      },
      onFailure: (failure) async =>
          setState(() => _error = failure.userMessage),
    );
    if (mounted) setState(() => _loading = false);
  }
}
