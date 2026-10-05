import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Tint for the New / Regular / Loyal patient status.
Color patientStatusColor(Patient patient) => switch (patient.statusLabel) {
  'Loyal' => AppColors.success,
  'Regular' => AppColors.aiPurple,
  _ => DashboardTokens.teal,
};

String patientInitials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'P';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

/// Short, stable display id derived from the record id (not an MRN).
String patientShortId(String id) {
  final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  final tail = clean.length <= 6 ? clean : clean.substring(clean.length - 6);
  return 'ID ${tail.toUpperCase()}';
}

/// Three-tier clinical patient card: identity header, recessed demographics
/// strip and a quick-action footer.
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
  Widget build(BuildContext context) {
    final statusColor = patientStatusColor(patient);
    return DashboardShadcnScope(
      child: shadcn.Card(
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
            // Header + body are the card's tap target (transparent Material
            // keeps the ripple above the card surface); footer buttons sit
            // outside it so they stay independently tappable.
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _IdentityHeader(
                        patient: patient,
                        statusColor: statusColor,
                        selectionMode: selectionMode,
                        selected: selected,
                        onSelectionChanged: onSelectionChanged,
                      ),
                      const SizedBox(height: 12),
                      _DemographicsStrip(patient: patient),
                    ],
                  ),
                ),
              ),
            ),
            if (!selectionMode) ...[
              shadcn.Divider(color: DashboardTokens.border(context)),
              _ActionFooter(
                onCall: patient.phone.trim().isEmpty ? null : onCall,
                onEdit: onEdit,
                onBookVisit: onBookVisit,
                onCreatePrescription: onCreatePrescription,
                onOpenRecords: onTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.patient,
    required this.statusColor,
    required this.selectionMode,
    required this.selected,
    required this.onSelectionChanged,
  });

  final Patient patient;
  final Color statusColor;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool?>? onSelectionChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (selectionMode) ...[
        shadcn.Checkbox(
          state: selected
              ? shadcn.CheckboxState.checked
              : shadcn.CheckboxState.unchecked,
          activeColor: DashboardTokens.teal,
          onChanged: onSelectionChanged == null
              ? null
              : (state) =>
                    onSelectionChanged!(state == shadcn.CheckboxState.checked),
        ),
        const SizedBox(width: 10),
      ],
      shadcn.Avatar(
        initials: patientInitials(patient.name),
        size: 46,
        borderRadius: 14,
        backgroundColor: statusColor.withValues(alpha: 0.12),
        theme: shadcn.AvatarTheme(
          textStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patient.name,
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
              patientShortId(patient.id),
              maxLines: 1,
              style: TextStyle(
                color: AppColors.subtleText(context),
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
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
            label: patient.statusLabel,
            color: statusColor,
            showDot: true,
          ),
          const SizedBox(height: 6),
          Text(
            '${patient.totalVisits} visit${patient.totalVisits == 1 ? '' : 's'}',
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ],
  );
}

/// Recessed 3-column strip: demographics, last visit and contact.
class _DemographicsStrip extends StatelessWidget {
  const _DemographicsStrip({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final gender = patient.gender?.trim();
    final demographics = [
      if (patient.age != null) '${patient.age} Yrs',
      if (gender != null && gender.isNotEmpty) gender,
    ].join(' • ');
    final visitDate = patient.lastVisit ?? patient.createdAt;
    Widget divider() => Container(
      width: 1,
      height: 32,
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
            child: _StripCell(
              icon: Icons.person_outline_rounded,
              label: 'Profile',
              value: demographics.isEmpty ? '—' : demographics,
            ),
          ),
          divider(),
          Expanded(
            child: _StripCell(
              icon: Icons.calendar_today_rounded,
              label: patient.lastVisit != null ? 'Last visit' : 'Registered',
              value: visitDate == null
                  ? '—'
                  : DateFormat('d MMM yy').format(visitDate),
            ),
          ),
          divider(),
          Expanded(
            child: _StripCell(
              icon: Icons.phone_outlined,
              label: 'Contact',
              value: patient.phone.trim().isEmpty ? '—' : patient.phone,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripCell extends StatelessWidget {
  const _StripCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 12, color: DashboardTokens.tealDeep),
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
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ],
  );
}

class _ActionFooter extends StatelessWidget {
  const _ActionFooter({
    required this.onCall,
    required this.onEdit,
    required this.onBookVisit,
    required this.onCreatePrescription,
    required this.onOpenRecords,
  });

  final VoidCallback? onCall;
  final VoidCallback? onEdit;
  final VoidCallback? onBookVisit;
  final VoidCallback? onCreatePrescription;
  final VoidCallback onOpenRecords;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 10, 10),
    child: Row(
      children: [
        _IconAction(
          icon: Icons.call_rounded,
          tooltip: 'Call patient',
          onPressed: onCall,
          color: AppColors.success,
        ),
        if (onEdit != null)
          _IconAction(
            icon: Icons.edit_outlined,
            tooltip: 'Edit patient',
            onPressed: onEdit,
          ),
        const SizedBox(width: 6),
        // Scales down rather than overflowing on narrow phones.
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onBookVisit != null)
                    shadcn.OutlineButton(
                      onPressed: onBookVisit,
                      size: shadcn.ButtonSize.small,
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                      ),
                      child: const Text('Book Visit'),
                    ),
                  if (onCreatePrescription != null) ...[
                    const SizedBox(width: 6),
                    shadcn.Button(
                      onPressed: onCreatePrescription,
                      leading: const Icon(Icons.add_rounded, size: 14),
                      style:
                          const shadcn.ButtonStyle.secondary(
                            size: shadcn.ButtonSize.small,
                          ).copyWith(
                            decoration: (context, states, value) =>
                                BoxDecoration(
                                  color: DashboardTokens.teal.withValues(
                                    alpha: states.contains(WidgetState.hovered)
                                        ? 0.18
                                        : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: DashboardTokens.teal.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                            textStyle: (context, states, value) =>
                                value.copyWith(
                                  color: DashboardTokens.tealDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                            iconTheme: (context, states, value) =>
                                value.copyWith(color: DashboardTokens.tealDeep),
                          ),
                      child: const Text('Create Rx'),
                    ),
                  ],
                  const SizedBox(width: 4),
                  shadcn.GhostButton(
                    onPressed: onOpenRecords,
                    size: shadcn.ButtonSize.small,
                    trailing: const Icon(Icons.chevron_right_rounded, size: 16),
                    child: const Text(
                      'Records',
                      style: TextStyle(
                        color: DashboardTokens.tealDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: shadcn.IconButton.ghost(
      onPressed: onPressed,
      size: shadcn.ButtonSize.small,
      icon: Icon(
        icon,
        size: 17,
        color: onPressed == null
            ? AppColors.subtleText(context)
            : color ?? AppColors.mutedText(context),
      ),
    ),
  );
}
