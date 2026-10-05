import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Shared look for the appointments feature: status tints, labels, the
/// pill selector and the form input decoration.

Color appointmentStatusColor(AppointmentStatus status) => switch (status) {
  AppointmentStatus.completed => AppColors.success,
  AppointmentStatus.cancelled => AppColors.destructive,
  AppointmentStatus.noShow => AppColors.textMuted,
  AppointmentStatus.confirmed => DashboardTokens.teal,
  AppointmentStatus.pending => AppColors.warning,
};

String appointmentStatusLabel(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pending => 'Pending',
  AppointmentStatus.confirmed => 'Confirmed',
  AppointmentStatus.completed => 'Completed',
  AppointmentStatus.cancelled => 'Cancelled',
  AppointmentStatus.noShow => 'No Show',
};

String appointmentPaymentLabel(AppointmentPaymentStatus status) =>
    switch (status) {
      AppointmentPaymentStatus.pending => 'Pending',
      AppointmentPaymentStatus.paid => 'Paid',
      AppointmentPaymentStatus.refunded => 'Refunded',
      AppointmentPaymentStatus.payAtClinic => 'Pay at clinic',
    };

Color appointmentPaymentColor(AppointmentPaymentStatus status) =>
    switch (status) {
      AppointmentPaymentStatus.pending => AppColors.warning,
      AppointmentPaymentStatus.paid => AppColors.success,
      AppointmentPaymentStatus.refunded => AppColors.textMuted,
      AppointmentPaymentStatus.payAtClinic => DashboardTokens.teal,
    };

/// Bordered input with a teal focus ring, used by appointment forms.
InputDecoration appointmentFieldDecoration(
  BuildContext context,
  String label, {
  String? hint,
  String? prefixText,
  IconData? icon,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(DashboardTokens.innerRadius),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 18, color: AppColors.subtleText(context)),
    hintStyle: TextStyle(color: AppColors.subtleText(context), fontSize: 13),
    labelStyle: TextStyle(color: AppColors.mutedText(context), fontSize: 13),
    floatingLabelStyle: const TextStyle(
      color: DashboardTokens.tealDeep,
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: AppColors.isDark(context) ? AppColors.darkCard : AppColors.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(DashboardTokens.border(context)),
    enabledBorder: border(DashboardTokens.border(context)),
    focusedBorder: border(DashboardTokens.teal, 1.8),
    errorBorder: border(AppColors.destructive.withValues(alpha: 0.6)),
    focusedErrorBorder: border(AppColors.destructive, 1.8),
  );
}

/// Small uppercase section label used to group form fields.
class AppointmentSectionLabel extends StatelessWidget {
  const AppointmentSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(), style: DashboardTokens.eyebrow(context)),
  );
}

/// A wrap of selectable pills built on shadcn [shadcn.Button]; replaces
/// Material dropdowns for short option lists. [onChanged] null disables it.
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({
    required this.options,
    required this.value,
    required this.labelOf,
    required this.onChanged,
    this.colorOf,
    this.iconOf,
    super.key,
  });

  final List<T> options;
  final T? value;
  final String Function(T option) labelOf;
  final ValueChanged<T>? onChanged;
  final Color Function(T option)? colorOf;
  final IconData Function(T option)? iconOf;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _pill(context, option, option == value, enabled),
      ],
    );
  }

  Widget _pill(BuildContext context, T option, bool selected, bool enabled) {
    final color = colorOf?.call(option) ?? DashboardTokens.teal;
    final foreground = selected ? color : AppColors.mutedText(context);
    final icon = selected ? Icons.check_rounded : iconOf?.call(option);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: shadcn.Button(
        enabled: enabled,
        onPressed: enabled ? () => onChanged!(option) : null,
        leading: icon == null ? null : Icon(icon, size: 14),
        style: const shadcn.ButtonStyle.outline(size: shadcn.ButtonSize.small)
            .copyWith(
              decoration: (context, states, value) => BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.12)
                    : AppColors.isDark(context)
                    ? AppColors.darkCard
                    : AppColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.5)
                      : DashboardTokens.border(context),
                ),
              ),
              textStyle: (context, states, value) => value.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              iconTheme: (context, states, value) =>
                  value.copyWith(color: foreground),
            ),
        child: Text(labelOf(option)),
      ),
    );
  }
}

/// Subtle drag handle for the appointment sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 14),
      decoration: BoxDecoration(
        color: DashboardTokens.border(context),
        borderRadius: BorderRadius.circular(999),
      ),
    ),
  );
}

/// Caps appointment sheets below full height so the backdrop above stays
/// visible (tap it to dismiss) instead of the sheet covering the screen.
BoxConstraints appointmentSheetConstraints(BuildContext context) =>
    BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88);

/// Close (X) button for the appointment sheet headers.
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Close',
    child: shadcn.IconButton.ghost(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: Icon(
        Icons.close_rounded,
        size: 20,
        color: AppColors.mutedText(context),
      ),
    ),
  );
}

const appointmentSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
);
