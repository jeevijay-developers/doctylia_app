import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment.dart';
import 'package:doctylia_app/features/appointments/domain/entities/appointment_query.dart';
import 'package:doctylia_app/features/appointments/presentation/providers/appointment_providers.dart';
import 'package:doctylia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

InputDecoration _fieldDecoration(String label, {String? prefixText}) =>
    InputDecoration(
      labelText: label,
      prefixText: prefixText,
      filled: true,
      fillColor: AppColors.primary.withValues(alpha: 0.035),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
    );

Future<void> showAppointmentForm(
  BuildContext context,
  WidgetRef ref, {
  Appointment? appointment,
  bool walkIn = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _AppointmentForm(appointment: appointment, walkIn: walkIn),
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

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.appointment == null
                        ? 'Add Appointment'
                        : 'Edit Appointment',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                decoration: _fieldDecoration('Patient name *'),
                validator: _required,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: _fieldDecoration('Phone number *'),
                validator: (value) {
                  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                  return digits.length == 10 ||
                          (digits.length == 12 && digits.startsWith('91'))
                      ? null
                      : 'Enter a valid 10-digit Indian phone number';
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration('Age'),
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
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: _fieldDecoration('Gender'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) => _gender = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _fieldDecoration('Email'),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return null;
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                      ? null
                      : 'Enter a valid email address';
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _service,
                decoration: _fieldDecoration('Service'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<AppointmentType>(
                      initialValue: _type,
                      decoration: _fieldDecoration('Visit type'),
                      items: const [
                        DropdownMenuItem(
                          value: AppointmentType.clinic,
                          child: Text('Clinic'),
                        ),
                        DropdownMenuItem(
                          value: AppointmentType.online,
                          child: Text('Online'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _type = value!),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration('Amount', prefixText: '₹ '),
                      validator: (value) =>
                          (double.tryParse(value ?? '') ?? 0) < 0
                          ? 'Cannot be negative'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<AppointmentPaymentStatus>(
                initialValue: _paymentStatus,
                decoration: _fieldDecoration('Payment status'),
                items: AppointmentPaymentStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_paymentLabel(status)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _paymentStatus = value!,
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: AppColors.primary,
                title: const Text('Walk-in'),
                subtitle: const Text('No fixed time slot'),
                value: _walkIn,
                onChanged: (value) => setState(() {
                  _walkIn = value;
                  if (!value) {
                    // Keep the chosen day but give it a bookable time.
                    final next = _nextQuarterHour(DateTime.now());
                    final onDay = DateTime(
                      _scheduled.year,
                      _scheduled.month,
                      _scheduled.day,
                      next.hour,
                      next.minute,
                    );
                    _scheduled = onDay.isBefore(next) ? next : onDay;
                  }
                }),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                onPressed: _pickDateTime,
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  _walkIn
                      ? '${DateFormat('d MMM yyyy').format(_scheduled)} · Walk-in'
                      : DateFormat('d MMM yyyy · h:mm a').format(_scheduled),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _complaint,
                decoration: _fieldDecoration('Chief complaint'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _notes,
                decoration: _fieldDecoration('Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: _saving ? null : _submit,
                child: Text(
                  _saving
                      ? 'Saving...'
                      : widget.appointment == null
                      ? 'Add appointment'
                      : 'Save changes',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
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

  static String _paymentLabel(AppointmentPaymentStatus status) =>
      switch (status) {
        AppointmentPaymentStatus.pending => 'Pending',
        AppointmentPaymentStatus.paid => 'Paid',
        AppointmentPaymentStatus.refunded => 'Refunded',
        AppointmentPaymentStatus.payAtClinic => 'Pay at clinic',
      };
}
