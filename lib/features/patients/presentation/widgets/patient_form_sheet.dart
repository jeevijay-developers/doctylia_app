import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';
import 'package:doctylia_app/features/patients/presentation/providers/patient_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showPatientForm(
  BuildContext context,
  WidgetRef ref, {
  Patient? patient,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PatientForm(patient: patient),
);

class _PatientForm extends ConsumerStatefulWidget {
  const _PatientForm({this.patient});
  final Patient? patient;

  @override
  ConsumerState<_PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends ConsumerState<_PatientForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _age;
  late final TextEditingController _notes;
  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final patient = widget.patient;
    _name = TextEditingController(text: patient?.name);
    _phone = TextEditingController(text: patient?.phone);
    _email = TextEditingController(text: patient?.email);
    _age = TextEditingController(text: patient?.age?.toString());
    _notes = TextEditingController(text: patient?.notes);
    _gender = patient?.gender?.toLowerCase();
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _email, _age, _notes]) {
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
          key: _key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.patient == null ? 'Add Patient' : 'Edit Patient',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone *'),
                validator: (value) {
                  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                  return digits.length == 10 ||
                          (digits.length == 12 && digits.startsWith('91'))
                      ? null
                      : 'Enter a valid 10-digit Indian phone number';
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: ['female', 'male', 'other']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                '${value[0].toUpperCase()}${value.substring(1)}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => _gender = value,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(
                  _saving
                      ? 'Saving...'
                      : widget.patient == null
                      ? 'Add patient'
                      : 'Save changes',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    final age = int.tryParse(_age.text);
    if (age != null && (age < 0 || age > 120)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Age must be between 0 and 120')),
      );
      return;
    }
    setState(() => _saving = true);
    final draft = PatientDraft(
      name: _name.text,
      phone: _phone.text,
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      age: age,
      gender: _gender,
      notes: _notes.text,
    );
    final controller = ref.read(patientsProvider.notifier);
    final error = widget.patient == null
        ? await controller.create(draft)
        : await controller.updatePatient(widget.patient!.id, draft);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.patient == null ? 'Patient added' : 'Patient updated',
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
