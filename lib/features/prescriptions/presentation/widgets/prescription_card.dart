import 'dart:io';

import 'package:doctylia_app/core/platform/file_download_service.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/prescriptions/application/prescription_pdf_service.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/presentation/providers/prescription_providers.dart';
import 'package:doctylia_app/features/prescriptions/presentation/widgets/prescription_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
      doctorName: doctor?.fullName,
      digitallySigned: doctor?.signatureUrl?.trim().isNotEmpty == true,
      generating: generating,
      selectionMode: widget.selectionMode,
      selected: widget.selected,
      onSelectionChanged: widget.onSelectionChanged,
      onOpen: _details,
      onShare: _sharePdf,
      onDownload: _downloadPdf,
    );
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
          final directory = await getTemporaryDirectory();
          final file = File(
            '${directory.path}${Platform.pathSeparator}prescription-${prescription.id}.pdf',
          );
          await file.writeAsBytes(bytes, flush: true);
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path, mimeType: 'application/pdf')],
              subject: 'Prescription for ${prescription.patientName}',
            ),
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
              .savePdf(
                fileName: _PrescriptionCardContent._pdfFileName(prescription),
                bytes: bytes,
              );
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

class _PrescriptionCardContent extends StatelessWidget {
  const _PrescriptionCardContent({
    required this.prescription,
    required this.digitallySigned,
    required this.generating,
    required this.selectionMode,
    required this.selected,
    required this.onOpen,
    required this.onShare,
    required this.onDownload,
    this.doctorName,
    this.onSelectionChanged,
  });

  final Prescription prescription;
  final String? doctorName;
  final bool digitallySigned;
  final bool generating;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool?>? onSelectionChanged;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final cleanDoctorName = doctorName?.trim();
    final author = cleanDoctorName == null || cleanDoctorName.isEmpty
        ? 'Doctor'
        : cleanDoctorName.startsWith('Dr.')
        ? cleanDoctorName
        : 'Dr. $cleanDoctorName';
    final medicineCount = prescription.medicines.isNotEmpty
        ? prescription.medicines.length
        : prescription.legacyMedications?.trim().isNotEmpty == true
        ? 1
        : 0;
    final diagnosis = prescription.diagnosis?.trim();
    final active = _isActive(prescription);
    final followUp = _followUpLabel(prescription.followUpDate);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context, alpha: 0.045),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: selectionMode
                ? () => onSelectionChanged?.call(!selected)
                : onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 13, 12, 11),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectionMode) ...[
                        Checkbox(
                          value: selected,
                          onChanged: onSelectionChanged,
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                      ] else ...[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary200.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                          child: const Icon(
                            Icons.note_add_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    prescription.patientName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.onSurface(context),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (active) const _ActiveRxBadge(),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Diagnosis:  '),
                                  TextSpan(
                                    text: diagnosis == null || diagnosis.isEmpty
                                        ? 'Not specified'
                                        : '"$diagnosis"',
                                    style: TextStyle(
                                      color: AppColors.mutedText(context),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.subtleText(context),
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 10,
                              runSpacing: 5,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondarySurface(context),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '$medicineCount ${medicineCount == 1 ? 'Drug' : 'Drugs'} prescribed',
                                    style: TextStyle(
                                      color: AppColors.mutedText(context),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (followUp != null)
                                  Text(
                                    '•  Follow-up: $followUp',
                                    style: TextStyle(
                                      color: AppColors.subtleText(context),
                                      fontSize: 10.5,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        DateFormat('d MMM yy').format(prescription.date),
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (!selectionMode) ...[
                    const SizedBox(height: 12),
                    _PrescriptionPdfRow(
                      fileName: _pdfFileName(prescription),
                      digitallySigned: digitallySigned,
                      generating: generating,
                      onOpen: onOpen,
                      onShare: onShare,
                      onDownload: onDownload,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!selectionMode) ...[
            Divider(height: 1, color: AppColors.border(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 5, 7, 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'By $author',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.subtleText(context),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: generating ? null : onShare,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: const Icon(Icons.share_outlined, size: 14),
                    label: const Text('Share'),
                  ),
                  TextButton(
                    onPressed: onOpen,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary600,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('View Rx →'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static bool _isActive(Prescription value) {
    final today = DateUtils.dateOnly(DateTime.now());
    final prescriptionDate = DateUtils.dateOnly(value.date);
    final followUpDate = value.followUpDate == null
        ? null
        : DateUtils.dateOnly(value.followUpDate!);
    return !prescriptionDate.isBefore(today) ||
        (followUpDate != null && !followUpDate.isBefore(today));
  }

  static String? _followUpLabel(DateTime? value) {
    if (value == null) return null;
    final days = DateUtils.dateOnly(
      value,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    if (days < 0) return null;
    if (days == 0) return 'Today';
    return '$days ${days == 1 ? 'Day' : 'Days'}';
  }

  static String _pdfFileName(Prescription value) {
    final patient = value.patientName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final date = DateFormat('dMMM').format(value.date);
    return 'Prescription_${date}_${patient.isEmpty ? 'Patient' : patient}.pdf';
  }
}

class _ActiveRxBadge extends StatelessWidget {
  const _ActiveRxBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
    ),
    child: const Text(
      'Active Rx',
      style: TextStyle(
        color: AppColors.success,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _PrescriptionPdfRow extends StatelessWidget {
  const _PrescriptionPdfRow({
    required this.fileName,
    required this.digitallySigned,
    required this.generating,
    required this.onOpen,
    required this.onShare,
    required this.onDownload,
  });

  final String fileName;
  final bool digitallySigned;
  final bool generating;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 8, 5, 8),
    decoration: BoxDecoration(
      color: AppColors.secondarySurface(context),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border(context)),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.pink.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.description_rounded,
            size: 15,
            color: AppColors.pink,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.onSurface(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                digitallySigned ? 'Digitally signed' : 'Prescription PDF',
                style: TextStyle(
                  color: AppColors.subtleText(context),
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
        _CardIconAction(
          tooltip: 'View prescription',
          icon: Icons.visibility_outlined,
          onPressed: onOpen,
        ),
        _CardIconAction(
          tooltip: 'Download prescription PDF',
          icon: Icons.download_rounded,
          loading: generating,
          onPressed: generating ? null : onDownload,
        ),
      ],
    ),
  );
}

class _CardIconAction extends StatelessWidget {
  const _CardIconAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    icon: loading
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          )
        : Icon(icon, size: 17, color: AppColors.primary600),
  );
}
