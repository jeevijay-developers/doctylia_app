import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PatientCard extends StatelessWidget {
  const PatientCard({
    required this.patient,
    required this.onTap,
    this.onEdit,
    this.onCall,
    this.onCreatePrescription,
    this.onBookVisit,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionChanged,
    super.key,
  });

  final Patient patient;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCall;
  final VoidCallback? onCreatePrescription;
  final VoidCallback? onBookVisit;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool?>? onSelectionChanged;

  @override
  Widget build(BuildContext context) => Container(
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 10, 11),
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
                      const SizedBox(width: 3),
                    ],
                    _PatientAvatar(patient: patient),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  patient.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.onSurface(context),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              _PatientStatusBadge(patient: patient),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (patient.age != null)
                                Text('${patient.age} Yrs', style: _metaStyle),
                              if (patient.age != null && _hasGender(patient))
                                const Text('•', style: _metaStyle),
                              if (_hasGender(patient))
                                Text(patient.gender!, style: _metaStyle),
                              if (patient.age != null || _hasGender(patient))
                                const Text('•', style: _metaStyle),
                              _VisitBadge(count: patient.totalVisits),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (onEdit != null)
                      IconButton(
                        onPressed: onEdit,
                        tooltip: 'Edit patient',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: AppColors.subtleText(context),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 19,
                        color: AppColors.subtleText(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: AppColors.border(context)),
                const SizedBox(height: 9),
                _ContactRow(
                  icon: Icons.phone_outlined,
                  value: patient.phone,
                  actionLabel: 'Call',
                  onAction: patient.phone.trim().isEmpty ? null : onCall,
                ),
                if (patient.email?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 7),
                  _ContactRow(
                    icon: Icons.alternate_email_rounded,
                    value: patient.email!,
                    trailing: patient.createdAt == null
                        ? null
                        : 'Registered: ${DateFormat('d MMM yyyy').format(patient.createdAt!)}',
                  ),
                ] else if (patient.createdAt != null) ...[
                  const SizedBox(height: 7),
                  _ContactRow(
                    icon: Icons.event_available_outlined,
                    value:
                        'Registered ${DateFormat('d MMM yyyy').format(patient.createdAt!)}',
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!selectionMode &&
            (onCreatePrescription != null || onBookVisit != null)) ...[
          Divider(height: 1, color: AppColors.border(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
            child: Row(
              children: [
                if (onCreatePrescription != null)
                  Expanded(
                    child: _QuickActionButton(
                      label: 'Create Rx',
                      icon: Icons.add_rounded,
                      onPressed: onCreatePrescription!,
                      filled: true,
                    ),
                  ),
                if (onCreatePrescription != null && onBookVisit != null)
                  const SizedBox(width: 8),
                if (onBookVisit != null)
                  Expanded(
                    child: _QuickActionButton(
                      label: 'Book Visit',
                      icon: Icons.calendar_today_outlined,
                      onPressed: onBookVisit!,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  static bool _hasGender(Patient patient) =>
      patient.gender?.trim().isNotEmpty == true;

  static const _metaStyle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 10.5,
  );
}

class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final color = switch (patient.statusLabel) {
      'Loyal' => AppColors.success,
      'Regular' => AppColors.aiPurple,
      _ => AppColors.teal,
    };
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.3),
      ),
      child: Text(
        _initials(patient.name),
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'P';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _PatientStatusBadge extends StatelessWidget {
  const _PatientStatusBadge({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final color = patient.totalVisits >= 10
        ? AppColors.success
        : patient.totalVisits >= 3
        ? AppColors.aiPurple
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        patient.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VisitBadge extends StatelessWidget {
  const _VisitBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      '$count visit${count == 1 ? '' : 's'}',
      style: const TextStyle(
        color: AppColors.success,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.value,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final IconData icon;
  final String value;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: AppColors.textLight),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5),
        ),
      ),
      if (trailing != null)
        Text(
          trailing!,
          style: const TextStyle(color: AppColors.textLight, fontSize: 8.5),
        ),
      if (actionLabel != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            visualDensity: VisualDensity.compact,
            foregroundColor: AppColors.primary600,
            textStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(actionLabel!),
        ),
    ],
  );
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        backgroundColor: filled ? AppColors.primary50 : Colors.transparent,
        foregroundColor: filled
            ? AppColors.primary600
            : AppColors.onSurface(context),
        side: BorderSide(
          color: filled ? AppColors.primary50 : AppColors.border(context),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label),
    ),
  );
}
