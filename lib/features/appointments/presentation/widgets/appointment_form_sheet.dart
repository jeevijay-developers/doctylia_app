import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment_query.dart';
import 'package:doctylia_app/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_ui.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

Future<void> showAppointmentForm(
  BuildContext context,
  WidgetRef ref, {
  Appointment? appointment,
  bool walkIn = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: appointmentSheetConstraints(context),
  shape: appointmentSheetShape,
  clipBehavior: Clip.antiAlias,
  builder: (_) => DashboardShadcnScope(
    child: _AppointmentForm(appointment: appointment, walkIn: walkIn),
  ),
);

class _AppointmentForm extends ConsumerStatefulWidget {
  const _AppointmentForm({this.appointment, this.walkIn = false});
  final Appointment? appointment;
  final bool walkIn;

  @override
  ConsumerState<_AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends ConsumerState<_AppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _age;
  late final TextEditingController _email;
  late final TextEditingController _service;
  late final TextEditingController _amount;
  late final TextEditingController _complaint;
  late final TextEditingController _notes;
  late DateTime _scheduled;
  late AppointmentType _type;
  late AppointmentPaymentStatus _paymentStatus;
  String? _gender;
  late bool _walkIn;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.appointment;
    final fee = ref.read(doctorProfileProvider)?.consultationFee ?? 0;
    _name = TextEditingController(text: item?.patientName);
    _phone = TextEditingController(text: item?.patientPhone);
    _age = TextEditingController(text: item?.patientAge?.toString());
    _email = TextEditingController(text: item?.patientEmail);
    _service = TextEditingController(text: item?.serviceName ?? 'Consultation');
    _amount = TextEditingController(
      text: item != null
          ? item.amount.toStringAsFixed(0)
          : fee <= 0
          ? ''
          : fee.toStringAsFixed(0),
    );
    _complaint = TextEditingController(text: item?.chiefComplaint);
    _notes = TextEditingController(text: item?.notes);
    _scheduled = item?.scheduledAt ?? _nextQuarterHour(DateTime.now());
    _type = item?.type ?? AppointmentType.clinic;
    _paymentStatus = item?.paymentStatus ?? AppointmentPaymentStatus.pending;
    _gender = item?.patientGender;
    _walkIn = item?.isWalkIn ?? widget.walkIn;
    if (_walkIn && item == null) {
      final now = DateTime.now();
      _scheduled = DateTime(now.year, now.month, now.day);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _age,
      _email,
      _service,
      _amount,
      _complaint,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  InputDecoration _field(
    String label, {
    String? hint,
    String? prefixText,
    IconData? icon,
  }) => appointmentFieldDecoration(
    context,
    label,
    hint: hint,
    prefixText: prefixText,
    icon: icon,
  );

  @override
  Widget build(BuildContext context) {
    final isNew = widget.appointment == null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Pinned header ──────────────────────────────────────────────
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const DashboardIconTile(
                  icon: Icons.event_available_rounded,
                  color: DashboardTokens.teal,
                  size: 42,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNew ? 'Book Appointment' : 'Edit Appointment',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        isNew
                            ? 'Schedule a visit for a new or returning patient'
                            : 'Update the visit details and schedule',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SheetCloseButton(),
              ],
            ),
          ),
          shadcn.Divider(color: DashboardTokens.border(context)),
          // ── Scrollable sectioned body ─────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FormSection(
                      step: 1,
                      icon: Icons.person_outline_rounded,
                      title: 'Patient',
                      subtitle: 'Who is the appointment for?',
                      children: [
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: _field(
                            'Patient name *',
                            hint: 'e.g. Ananya Sharma',
                            icon: Icons.badge_outlined,
                          ),
                          validator: _required,
                        ),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: _field(
                            'Phone number *',
                            hint: '10-digit mobile number',
                            icon: Icons.phone_outlined,
                          ),
                          validator: (value) {
                            final digits = (value ?? '').replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            return digits.length == 10 ||
                                    (digits.length == 12 &&
                                        digits.startsWith('91'))
                                ? null
                                : 'Enter a valid 10-digit Indian phone number';
                          },
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 92,
                              child: TextFormField(
                                controller: _age,
                                keyboardType: TextInputType.number,
                                decoration: _field('Age', hint: 'Years'),
                                validator: (value) {
                                  final text = (value ?? '').trim();
                                  if (text.isEmpty) return null;
                                  final age = int.tryParse(text);
                                  return age != null && age >= 0 && age <= 120
                                      ? null
                                      : 'Enter an age from 0 to 120';
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _field(
                                  'Email',
                                  hint: 'name@example.com',
                                ),
                                validator: (value) {
                                  final email = (value ?? '').trim();
                                  if (email.isEmpty) return null;
                                  return RegExp(
                                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                      ).hasMatch(email)
                                      ? null
                                      : 'Enter a valid email address';
                                },
                              ),
                            ),
                          ],
                        ),
                        _LabeledPills(
                          label: 'Gender',
                          child: ChoicePills<String>(
                            options: const ['male', 'female', 'other'],
                            value: _gender,
                            labelOf: (value) => switch (value) {
                              'male' => 'Male',
                              'female' => 'Female',
                              _ => 'Other',
                            },
                            onChanged: (value) =>
                                setState(() => _gender = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FormSection(
                      step: 2,
                      icon: Icons.calendar_month_outlined,
                      title: 'Schedule',
                      subtitle: 'Pick a slot or mark as a walk-in',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Walk-in',
                                    style: TextStyle(
                                      color: AppColors.onSurface(context),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'No fixed time slot',
                                    style: TextStyle(
                                      color: AppColors.mutedText(context),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            shadcn.Switch(
                              value: _walkIn,
                              activeColor: DashboardTokens.teal,
                              onChanged: (value) => setState(() {
                                _walkIn = value;
                                if (!value) {
                                  // Keep the chosen day but give it a
                                  // bookable time.
                                  final next = _nextQuarterHour(DateTime.now());
                                  final onDay = DateTime(
                                    _scheduled.year,
                                    _scheduled.month,
                                    _scheduled.day,
                                    next.hour,
                                    next.minute,
                                  );
                                  _scheduled = onDay.isBefore(next)
                                      ? next
                                      : onDay;
                                }
                              }),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _SlotTile(
                                icon: Icons.calendar_today_rounded,
                                label: 'Date',
                                value: DateFormat(
                                  'EEE, d MMM yyyy',
                                ).format(_scheduled),
                                onTap: _pickDateTime,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: _SlotTile(
                                icon: Icons.schedule_rounded,
                                label: 'Time',
                                value: _walkIn
                                    ? 'Walk-in'
                                    : DateFormat('h:mm a').format(_scheduled),
                                onTap: _pickDateTime,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FormSection(
                      step: 3,
                      icon: Icons.medical_services_outlined,
                      title: 'Appointment details',
                      subtitle: 'Visit type, fee and clinical notes',
                      children: [
                        TextFormField(
                          controller: _service,
                          decoration: _field(
                            'Service',
                            hint: 'e.g. Consultation',
                            icon: Icons.medical_information_outlined,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _LabeledPills(
                                label: 'Visit type',
                                child: ChoicePills<AppointmentType>(
                                  options: const [
                                    AppointmentType.clinic,
                                    AppointmentType.online,
                                  ],
                                  value: _type,
                                  labelOf: (value) =>
                                      value == AppointmentType.clinic
                                      ? 'Clinic'
                                      : 'Online',
                                  iconOf: (value) =>
                                      value == AppointmentType.clinic
                                      ? Icons.local_hospital_outlined
                                      : Icons.videocam_outlined,
                                  onChanged: (value) =>
                                      setState(() => _type = value),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            SizedBox(
                              width: 112,
                              child: TextFormField(
                                controller: _amount,
                                keyboardType: TextInputType.number,
                                decoration: _field('Amount', prefixText: '₹ '),
                                validator: (value) =>
                                    (double.tryParse(value ?? '') ?? 0) < 0
                                    ? 'Cannot be negative'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        _LabeledPills(
                          label: 'Payment status',
                          child: ChoicePills<AppointmentPaymentStatus>(
                            options: AppointmentPaymentStatus.values,
                            value: _paymentStatus,
                            labelOf: appointmentPaymentLabel,
                            colorOf: appointmentPaymentColor,
                            onChanged: (value) =>
                                setState(() => _paymentStatus = value),
                          ),
                        ),
                        TextFormField(
                          controller: _complaint,
                          decoration: _field(
                            'Chief complaint',
                            hint: 'Reason for visit',
                          ),
                          maxLines: 2,
                          buildCounter: _characterCount,
                        ),
                        TextFormField(
                          controller: _notes,
                          decoration: _field(
                            'Notes',
                            hint: 'Anything the team should know',
                          ),
                          maxLines: 3,
                          buildCounter: _characterCount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Pinned action bar ─────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: DashboardTokens.border(context)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      height: 48,
                      child: shadcn.OutlineButton(
                        alignment: Alignment.center,
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: shadcn.PrimaryButton(
                          alignment: Alignment.center,
                          onPressed: _saving ? null : _submit,
                          leading: _saving
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  isNew
                                      ? Icons.add_rounded
                                      : Icons.check_rounded,
                                  size: 18,
                                ),
                          child: Text(
                            _saving
                                ? 'Saving...'
                                : isNew
                                ? 'Add appointment'
                                : 'Save changes',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
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

  /// Display-only character count; no `maxLength`, so input is never capped.
  Widget? _characterCount(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => Text(
    '$currentLength characters',
    style: TextStyle(color: AppColors.subtleText(context), fontSize: 11),
  );

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'This field is required' : null;

  static DateTime _nextQuarterHour(DateTime now) {
    final candidate = now.add(const Duration(hours: 1));
    final minutesToAdd = (15 - candidate.minute % 15) % 15;
    final rounded = candidate.add(Duration(minutes: minutesToAdd));
    return DateTime(
      rounded.year,
      rounded.month,
      rounded.day,
      rounded.hour,
      rounded.minute,
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _scheduled.isBefore(now) ? now : _scheduled;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    if (_walkIn) {
      setState(() => _scheduled = DateTime(date.year, date.month, date.day));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time != null) {
      setState(() {
        _scheduled = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final draft = AppointmentDraft(
      patientName: _name.text,
      patientPhone: _phone.text,
      patientAge: int.tryParse(_age.text),
      patientGender: _gender,
      patientEmail: _email.text,
      serviceName: _service.text,
      scheduledAt: _scheduled,
      amount: double.tryParse(_amount.text) ?? 0,
      type: _type,
      paymentStatus: _paymentStatus,
      chiefComplaint: _complaint.text,
      notes: _notes.text,
      isWalkIn: _walkIn,
    );
    String? error;
    try {
      final controller = ref.read(appointmentsProvider.notifier);
      error = widget.appointment == null
          ? await controller.create(draft)
          : await controller.updateAppointment(widget.appointment!.id, draft);
    } on AppFailure catch (failure) {
      error = failure.userMessage;
    } catch (_) {
      error = 'The appointment could not be saved. Please try again.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.appointment == null
                ? 'Appointment added'
                : 'Appointment updated',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

/// Card-style group of related form fields with a numbered header.
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final int step;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.isDark(context) ? AppColors.darkCard : AppColors.card,
      borderRadius: BorderRadius.circular(DashboardTokens.radius),
      border: Border.all(color: DashboardTokens.border(context)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.secondarySurface(context).withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(DashboardTokens.radius),
            ),
            border: Border(
              bottom: BorderSide(color: DashboardTokens.border(context)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DashboardTokens.teal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: DashboardTokens.tealDeep,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.onSurface(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.mutedText(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(icon, size: 18, color: AppColors.subtleText(context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _LabeledPills extends StatelessWidget {
  const _LabeledPills({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: AppColors.mutedText(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}

/// A tappable date/time slot that opens the picker.
class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DashboardTokens.innerRadius);
    return Material(
      color: DashboardTokens.teal.withValues(alpha: 0.06),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: DashboardTokens.teal.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: DashboardTokens.tealDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.mutedText(context),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.onSurface(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
