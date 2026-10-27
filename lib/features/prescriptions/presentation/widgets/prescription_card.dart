
import 'package:doctylia_app/core/platform/file_download_service.dart';
import 'package:doctylia_app/core/platform/shared_file_cache.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/widgets/app_motion.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/prescriptions/application/prescription_pdf_service.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription_status.dart';
import 'package:doctylia_app/features/prescriptions/presentation/providers/prescription_providers.dart';
import 'package:doctylia_app/features/prescriptions/presentation/widgets/prescription_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class PrescriptionCard extends ConsumerStatefulWidget {
  const PrescriptionCard({
    required this.prescription,
    this.readOnly = false,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionChanged,
    super.key,
  });
  final Prescription prescription;
  final bool readOnly;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool?>? onSelectionChanged;
  @override
  ConsumerState<PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends ConsumerState<PrescriptionCard> {
  bool generating = false;
  Prescription get prescription => widget.prescription;

  @override
  Widget build(BuildContext context) {
    final doctor = ref.watch(doctorProfileProvider);
    return _PrescriptionCardContent(
      prescription: prescription,
      status: prescriptionStatusOf(prescription),
      doctorName: doctor?.fullName,
      doctorSpecialty: doctor?.specialization,
      digitallySigned: doctor?.signatureUrl?.trim().isNotEmpty == true,
      generating: generating,
      selectionMode: widget.selectionMode,
      selected: widget.selected,
      onSelectionChanged: widget.onSelectionChanged,
      onOpen: _details,
      onShare: _sharePdf,
      onDownload: _downloadPdf,
      onRenew: widget.readOnly ? null : _renew,
    );
  }

  /// Opens the form prefilled from this prescription; saves a new one
  /// dated today, leaving this record unchanged.
  Future<void> _renew() async {
    ref.invalidate(prescriptionPatientsProvider);
    final renewed = await showPrescriptionForm(
      context,
      ref,
      template: prescription,
    );
    if (renewed != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prescription renewed')));
    }
  }

  Future<void> _details() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prescription.patientName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Issued ${DateFormat('d MMMM yyyy').format(prescription.date)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.onSurface(
                          context,
                        ).withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _label('Diagnosis', Icons.medical_information_rounded),
          Text(prescription.diagnosis ?? 'Not specified'),
          const SizedBox(height: AppSpacing.md),
          _label('Medicines', Icons.medication_rounded),
          if (prescription.medicines.isEmpty)
            Text(prescription.legacyMedications ?? 'No medicines recorded')
          else
            ...prescription.medicines.indexed.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${entry.$1 + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.$2.name}${entry.$2.strength.isEmpty ? '' : ' - ${entry.$2.strength}'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            entry.$2.slipLine,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.onSurface(
                                context,
                              ).withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (prescription.advice != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _label('General advice', Icons.tips_and_updates_rounded),
            Text(prescription.advice!),
          ],
          if (prescription.dietAdvice != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _label('Diet advice', Icons.restaurant_rounded),
            Text(prescription.dietAdvice!),
          ],
          if (prescription.lifestyleAdvice != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _label('Lifestyle advice', Icons.directions_run_rounded),
            Text(prescription.lifestyleAdvice!),
          ],
          if (prescription.followUpDate != null ||
              prescription.followUpInstructions != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _label('Follow-up', Icons.event_repeat_rounded),
            Text(
              [
                if (prescription.followUpDate != null)
                  DateFormat('d MMMM yyyy').format(prescription.followUpDate!),
                prescription.followUpInstructions,
              ].whereType<String>().join(' · '),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _label('Notes', Icons.sticky_note_2_rounded),
          Text(prescription.notes ?? 'No notes'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _sharePdf();
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share PDF'),
                ),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await showPrescriptionForm(
                        context,
                        ref,
                        prescription: prescription,
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ],
          ),
          if (!widget.readOnly)
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                ),
                onPressed: () => _delete(sheetContext),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete prescription'),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _label(String text, [IconData? icon]) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Future<void> _sharePdf() async {
    if (generating) return;
    final profile = ref.read(doctorProfileProvider);
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor profile is unavailable.')),
      );
      return;
    }
    setState(() => generating = true);
    final detailsResult = await ref
        .read(prescriptionRepositoryProvider)
        .getSlipDetails(prescription);
    if (!mounted) return;
    await detailsResult.fold(
      onSuccess: (details) async {
        try {
          final bytes = await PrescriptionPdfService.generate(
            profile: profile,
            prescription: prescription,
            details: details,
          );
          await SharedFileCache.shareBytes(
            fileName: 'prescription-${prescription.id}.pdf',
            bytes: bytes,
            mimeType: 'application/pdf',
            subject: 'Prescription for ${prescription.patientName}',
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not generate the prescription PDF.'),
              ),
            );
          }
        }
      },
      onFailure: (failure) async => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage))),
    );
    if (mounted) setState(() => generating = false);
  }

  Future<void> _downloadPdf() async {
    if (generating) return;
    final profile = ref.read(doctorProfileProvider);
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor profile is unavailable.')),
      );
      return;
    }
    setState(() => generating = true);
    try {
      final detailsResult = await ref
          .read(prescriptionRepositoryProvider)
          .getSlipDetails(prescription);
      if (!mounted) return;
      await detailsResult.fold(
        onSuccess: (details) async {
          final bytes = await PrescriptionPdfService.generate(
            profile: profile,
            prescription: prescription,
            details: details,
          );
          await ref
              .read(fileDownloadServiceProvider)
              .savePdf(fileName: _pdfFileName(prescription), bytes: bytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Prescription downloaded.')),
            );
          }
        },
        onFailure: (failure) async {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
          }
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not download the prescription PDF.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> _delete(BuildContext sheetContext) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: const Text('Delete prescription?'),
        content: const Text('This prescription will be permanently removed.'),
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
    if (confirmed != true) return;
    final error = await ref
        .read(prescriptionsProvider.notifier)
        .delete(prescription.id);
    if (!mounted) return;
    if (error == null && sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

/// PDF file name for download/share: `Prescription_12Oct_Ananya_Sharma.pdf`.
String _pdfFileName(Prescription value) {
  final patient = value.patientName
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final date = DateFormat('dMMM').format(value.date);
  return 'Prescription_${date}_${patient.isEmpty ? 'Patient' : patient}.pdf';
}

(String, Color, IconData) _statusStyle(
  BuildContext context,
  PrescriptionStatus status,
) => switch (status) {
  PrescriptionStatus.active => (
    'Active',
    AppColors.success,
    Icons.check_circle_rounded,
  ),
  PrescriptionStatus.followUpDue => (
    'Follow-up due',
    AppColors.warning,
    Icons.event_repeat_rounded,
  ),
  PrescriptionStatus.completed => (
    'Completed',
    AppColors.mutedText(context),
    Icons.task_alt_rounded,
  ),
};

/// The dashboard shadcn theme with a medical-teal primary, so primary
/// buttons on the Prescriptions screen and its cards read as one accent.
class PrescriptionShadcnScope extends StatelessWidget {
  const PrescriptionShadcnScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      DashboardShadcnScope(primary: DashboardTokens.tealDeep, child: child);
}

/// Loading placeholder with the card's exact structure; render it inside a
/// [Skeleton] so every block matches the loaded card (no layout shift).
class PrescriptionCardSkeleton extends StatelessWidget {
  const PrescriptionCardSkeleton({super.key});

  static final _placeholder = Prescription(
    id: 'skeleton',
    patientName: 'Patient Name',
    date: DateTime(2026),
    patientAge: 30,
    patientWeight: 60,
    diagnosis: 'Diagnosis text',
    medicines: const [
      MedicineItem(
        name: 'Medicine name',
        strength: '500mg',
        morning: true,
        evening: true,
        durationDays: 5,
      ),
      MedicineItem(
        name: 'Medicine name',
        strength: '10mg',
        evening: true,
        durationDays: 7,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => _PrescriptionCardContent(
    prescription: _placeholder,
    status: PrescriptionStatus.active,
    doctorName: 'Doctor Name',
    doctorSpecialty: 'Specialty',
    digitallySigned: false,
    generating: false,
    selectionMode: false,
    selected: false,
    onOpen: () {},
    onShare: () {},
    onDownload: () {},
    onRenew: () {},
  );
}

/// 3-tier clinical card: patient & Rx meta → recessed medication panel →
/// quick actions.
class _PrescriptionCardContent extends StatelessWidget {
  const _PrescriptionCardContent({
    required this.prescription,
    required this.status,
    required this.digitallySigned,
    required this.generating,
    required this.selectionMode,
    required this.selected,
    required this.onOpen,
    required this.onShare,
    required this.onDownload,
    this.onRenew,
    this.doctorName,
    this.doctorSpecialty,
    this.onSelectionChanged,
  });

  final Prescription prescription;
  final PrescriptionStatus status;
  final String? doctorName;
  final String? doctorSpecialty;
  final bool digitallySigned;
  final bool generating;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool?>? onSelectionChanged;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDownload;

  /// Null hides the Renew action (read-only trial grace access).
  final VoidCallback? onRenew;

  static const _maxMedicineLines = 3;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusIcon) = _statusStyle(
      context,
      status,
    );
    return PrescriptionShadcnScope(
      child: AppPressScale(
        builder: (onHighlight) => shadcn.Card(
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(DashboardTokens.radius),
          borderColor: selectionMode && selected
              ? DashboardTokens.teal.withValues(alpha: 0.6)
              : DashboardTokens.border(context),
          boxShadow: DashboardTokens.shadow(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header + body are the tap target; the footer's buttons sit
              // outside it so they stay independently tappable.
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: selectionMode
                      ? () => onSelectionChanged?.call(!selected)
                      : onOpen,
                  onHighlightChanged: onHighlight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(context, statusLabel, statusColor, statusIcon),
                        const SizedBox(height: 12),
                        _medicationPanel(context),
                        const SizedBox(height: 10),
                        _doctorRow(context),
                      ],
                    ),
                  ),
                ),
              ),
              if (!selectionMode) ...[
                shadcn.Divider(color: DashboardTokens.border(context)),
                _footer(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Tier 1: patient & Rx meta ─────────────────────────────────────────
  Widget _header(
    BuildContext context,
    String statusLabel,
    Color statusColor,
    IconData statusIcon,
  ) {
    final meta = [
      if (prescription.patientAge != null) '${prescription.patientAge} yrs',
      if (prescription.patientWeight != null)
        '${_trimNumber(prescription.patientWeight!)} kg',
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectionMode)
          Checkbox(
            value: selected,
            onChanged: onSelectionChanged,
            visualDensity: VisualDensity.compact,
          )
        else
          shadcn.Avatar(
            initials: shadcn.Avatar.getInitials(prescription.patientName),
            size: 42,
            backgroundColor: DashboardTokens.teal.withValues(alpha: 0.14),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prescription.patientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                meta.isEmpty ? 'Age & weight not recorded' : meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.subtleText(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            DashboardToneBadge(
              label: statusLabel,
              color: statusColor,
              icon: statusIcon,
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('d MMM yyyy').format(prescription.date),
              style: TextStyle(
                color: AppColors.mutedText(context),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tier 2: recessed medication & dosage panel ────────────────────────
  Widget _medicationPanel(BuildContext context) {
    final diagnosis = prescription.diagnosis?.trim();
    final medicines = prescription.medicines;
    final legacy = prescription.legacyMedications?.trim();
    final followUp = _followUpText(prescription.followUpDate);
    final hidden = medicines.length - _maxMedicineLines;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
        border: Border.all(
          color: DashboardTokens.border(context).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (diagnosis != null && diagnosis.isNotEmpty) ...[
            _PanelLabel(
              icon: Icons.medical_information_outlined,
              label: 'Diagnosis',
              value: diagnosis,
            ),
            const SizedBox(height: 10),
          ],
          if (medicines.isEmpty)
            Text(
              legacy == null || legacy.isEmpty
                  ? 'No medicines recorded'
                  : legacy,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.onSurface(context),
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          else
            for (final (i, item)
                in medicines.take(_maxMedicineLines).indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              _MedicineLine(item: item),
            ],
          if (hidden > 0) ...[
            const SizedBox(height: 8),
            Text(
              '+$hidden more ${hidden == 1 ? 'medicine' : 'medicines'}',
              style: const TextStyle(
                color: DashboardTokens.tealDeep,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (followUp != null) ...[
            const SizedBox(height: 10),
            _PanelLabel(
              icon: Icons.event_repeat_rounded,
              label: 'Follow-up',
              value: followUp,
            ),
          ],
        ],
      ),
    );
  }

  Widget _doctorRow(BuildContext context) {
    final clean = doctorName?.trim();
    final author = clean == null || clean.isEmpty
        ? 'Doctor'
        : clean.startsWith('Dr.')
        ? clean
        : 'Dr. $clean';
    final specialty = doctorSpecialty?.trim();
    return Row(
      children: [
        Icon(
          digitallySigned ? Icons.verified_rounded : Icons.person_outline,
          size: 14,
          color: digitallySigned
              ? DashboardTokens.tealDeep
              : AppColors.subtleText(context),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (specialty != null && specialty.isNotEmpty) ...[
          const SizedBox(width: 6),
          Flexible(
            child: _Tag(text: specialty, color: DashboardTokens.tealDeep),
          ),
        ],
      ],
    );
  }

  // ── Tier 3: quick clinical actions ────────────────────────────────────
  Widget _footer(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 10, 10),
    child: Row(
      children: [
        Tooltip(
          message: 'Share prescription PDF',
          child: shadcn.IconButton.ghost(
            onPressed: generating ? null : onShare,
            density: shadcn.ButtonDensity.icon,
            icon: const Icon(Icons.share_outlined, size: 18),
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: 'Download prescription PDF',
          child: shadcn.IconButton.outline(
            onPressed: generating ? null : onDownload,
            density: shadcn.ButtonDensity.icon,
            icon: Icon(
              generating ? Icons.hourglass_top_rounded : Icons.download_rounded,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          // Scales down rather than overflowing on narrow phones or with
          // large accessibility text.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRenew != null) ...[
                  shadcn.SecondaryButton(
                    onPressed: onRenew,
                    size: shadcn.ButtonSize.small,
                    leading: const Icon(Icons.autorenew_rounded, size: 15),
                    child: const Text('Renew'),
                  ),
                  const SizedBox(width: 6),
                ],
                shadcn.PrimaryButton(
                  onPressed: onOpen,
                  size: shadcn.ButtonSize.small,
                  trailing: const Icon(Icons.arrow_forward_rounded, size: 15),
                  child: const Text('View Details'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  static String _trimNumber(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  static String? _followUpText(DateTime? value) {
    if (value == null) return null;
    final days = DateUtils.dateOnly(
      value,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    final date = DateFormat('d MMM').format(value);
    if (days == 0) return 'Today ($date)';
    if (days == 1) return 'Tomorrow ($date)';
    if (days > 1) return 'In $days days ($date)';
    if (days == -1) return 'Was yesterday ($date)';
    return 'Was ${-days} days ago ($date)';
  }
}

/// One structured medicine: "Name · strength" + regimen chips.
class _MedicineLine extends StatelessWidget {
  const _MedicineLine({required this.item});

  final MedicineItem item;

  @override
  Widget build(BuildContext context) {
    final strength = item.strength.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.medication_rounded,
              size: 15,
              color: DashboardTokens.tealDeep,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: item.name.trim().isEmpty ? 'Medicine' : item.name,
                  style: TextStyle(
                    color: AppColors.onSurface(context),
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    if (strength.isNotEmpty)
                      TextSpan(
                        text: '  ·  $strength',
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 21),
          child: Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              _Tag(
                icon: Icons.schedule_rounded,
                text: item.schedule,
                color: AppColors.primary600,
              ),
              _Tag(
                icon: Icons.restaurant_rounded,
                text: item.food == MedicineFood.before
                    ? 'Before food'
                    : 'After food',
                color: DashboardTokens.tealDeep,
              ),
              if (item.durationDays > 0)
                _Tag(
                  icon: Icons.timelapse_rounded,
                  text:
                      '${item.durationDays} ${item.durationDays == 1 ? 'day' : 'days'}',
                  color: AppColors.mutedText(context),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small tinted metadata chip (dosage, food timing, duration, specialty).
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.isDark(context)
          ? color.withValues(alpha: 0.16)
          : Color.alphaBlend(color.withValues(alpha: 0.08), AppColors.card),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

/// "Diagnosis  Acute bronchitis" style labelled line inside the panel.
class _PanelLabel extends StatelessWidget {
  const _PanelLabel({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: AppColors.subtleText(context)),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: AppColors.subtleText(context),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.onSurface(context),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
