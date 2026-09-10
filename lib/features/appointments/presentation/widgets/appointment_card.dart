import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_form_sheet.dart';
import 'package:doctylia_app/shared/entitlements/feature_access.dart';
import 'package:doctylia_app/shared/entitlements/feature_gate.dart';
import 'package:doctylia_app/shared/entitlements/plan_status.dart';
import 'package:doctylia_app/shared/entitlements/trial_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

InputDecoration _fieldDecoration(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: AppColors.primary.withValues(alpha: 0.035),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide.none,
  ),
);

Color _statusColor(AppointmentStatus status) => switch (status) {
  AppointmentStatus.completed => AppColors.success,
  AppointmentStatus.cancelled => AppColors.destructive,
  AppointmentStatus.noShow => AppColors.textMuted,
  AppointmentStatus.confirmed => AppColors.primary,
  AppointmentStatus.pending => AppColors.warning,
};

class AppointmentCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor(appointment.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context, alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selectionMode
            ? onSelected
            : () => showAppointmentDetails(context, appointment),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 11, 10),
                  child: Row(
                    children: [
                      if (selectionMode) ...[
                        Checkbox(
                          value: selected,
                          activeColor: AppColors.primary,
                          onChanged: (_) => onSelected?.call(),
                        ),
                        const SizedBox(width: 4),
                      ],
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: color.withValues(alpha: 0.09),
                        foregroundColor: color,
                        child: Text(
                          appointment.patientName.isEmpty
                              ? 'P'
                              : appointment.patientName[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 9),
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
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              appointment.serviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.mutedText(context),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 11,
                                  color: AppColors.subtleText(context),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'EEE, d MMM • h:mm a',
                                    ).format(appointment.scheduledAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: AppColors.subtleText(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              _statusLabel(appointment.status),
                              style: TextStyle(
                                color: color,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${appointment.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppColors.onSurface(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (appointment.type == AppointmentType.online) ...[
                            const SizedBox(height: 2),
                            const Icon(
                              Icons.videocam_rounded,
                              size: 13,
                              color: AppColors.teal,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showAppointmentDetails(
  BuildContext context,
  Appointment appointment,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _AppointmentDetails(appointment: appointment),
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
    final color = _statusColor(appointment.status);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: color.withValues(alpha: 0.12),
                    foregroundColor: color,
                    child: Text(
                      appointment.patientName.isEmpty
                          ? 'P'
                          : appointment.patientName[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
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
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${appointment.serviceName} · ${appointment.type.name}',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(
                icon: Icons.phone_rounded,
                text: appointment.patientPhone,
              ),
              _InfoRow(
                icon: Icons.event_rounded,
                text: DateFormat(
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
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<AppointmentStatus>(
                initialValue: appointment.status,
                decoration: _fieldDecoration('Status'),
                items:
                    const [
                          AppointmentStatus.pending,
                          AppointmentStatus.confirmed,
                          AppointmentStatus.completed,
                          AppointmentStatus.cancelled,
                          AppointmentStatus.noShow,
                        ]
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(_statusLabel(status)),
                          ),
                        )
                        .toList(),
                onChanged: writeDisabled || _changing
                    ? null
                    : (status) => _changeStatus(status),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<AppointmentPaymentStatus>(
                initialValue: appointment.paymentStatus,
                decoration: _fieldDecoration('Payment status'),
                items: AppointmentPaymentStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_paymentLabel(status)),
                      ),
                    )
                    .toList(),
                onChanged: writeDisabled || _changing
                    ? null
                    : (status) => _changePayment(status),
              ),
              if (appointment.type == AppointmentType.online) ...[
                const SizedBox(height: AppSpacing.md),
                FeatureGate(
                  feature: FeatureKey.onlineConsultation,
                  lockedChild: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Online Consultation',
                                style: TextStyle(fontWeight: FontWeight.w700),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
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
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    onPressed: writeDisabled ? null : _delete,
                    color: AppColors.destructive,
                    tooltip: 'Delete appointment',
                    icon: const Icon(Icons.delete_outline_rounded),
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
                    borderRadius: BorderRadius.circular(AppRadius.sm),
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
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text)),
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
        color: AppColors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  size: 16,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Text(
                'Video Consultation · Zoom',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_error!, style: const TextStyle(color: AppColors.destructive)),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
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
                  : const Icon(Icons.open_in_new_rounded),
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

String _statusLabel(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => 'Pending',
  AppointmentStatus.confirmed => 'Confirmed',
  AppointmentStatus.completed => 'Completed',
  AppointmentStatus.cancelled => 'Cancelled',
  AppointmentStatus.noShow => 'No Show',
};

String _paymentLabel(AppointmentPaymentStatus status) => switch (status) {
  AppointmentPaymentStatus.pending => 'Pending',
  AppointmentPaymentStatus.paid => 'Paid',
  AppointmentPaymentStatus.refunded => 'Refunded',
  AppointmentPaymentStatus.payAtClinic => 'Pay at clinic',
};
