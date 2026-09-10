import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/presentation/providers/prescription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

Future<Prescription?> showPrescriptionForm(
  BuildContext context,
  WidgetRef ref, {
  Prescription? prescription,
}) => showModalBottomSheet<Prescription>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _PrescriptionForm(prescription: prescription),
);

InputDecoration _fieldDecoration(
  String label, {
  Widget? suffixIcon,
  String? hintText,
}) => InputDecoration(
  labelText: label,
  hintText: hintText,
  suffixIcon: suffixIcon,
  filled: true,
  fillColor: AppColors.primary.withOpacity(0.035),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide.none,
  ),
);

class _PrescriptionForm extends ConsumerStatefulWidget {
  const _PrescriptionForm({this.prescription});
  final Prescription? prescription;
  @override
  ConsumerState<_PrescriptionForm> createState() => _PrescriptionFormState();
}

class _PrescriptionFormState extends ConsumerState<_PrescriptionForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController patient;
  late final TextEditingController diagnosis;
  late final TextEditingController age;
  late final TextEditingController weight;
  late final TextEditingController notes;
  late final TextEditingController advice;
  late final TextEditingController dietAdvice;
  late final TextEditingController lifestyleAdvice;
  late final TextEditingController followUpInstructions;
  late DateTime date;
  DateTime? followUpDate;
  String? patientId;
  String? visitId;
  final medicineRows = <_MedicineControllers>[];
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final value = widget.prescription;
    patient = TextEditingController(text: value?.patientName);
    diagnosis = TextEditingController(text: value?.diagnosis);
    age = TextEditingController(text: value?.patientAge?.toString());
    weight = TextEditingController(text: value?.patientWeight?.toString());
    notes = TextEditingController(text: value?.notes);
    advice = TextEditingController(text: value?.advice);
    dietAdvice = TextEditingController(text: value?.dietAdvice);
    lifestyleAdvice = TextEditingController(text: value?.lifestyleAdvice);
    followUpInstructions = TextEditingController(
      text: value?.followUpInstructions,
    );
    date = value?.date ?? DateTime.now();
    followUpDate = value?.followUpDate;
    patientId = value?.patientId;
    visitId = value?.visitId;
    medicineRows.addAll(
      value?.medicines.map(_MedicineControllers.fromItem) ??
          [_MedicineControllers()],
    );
    if (medicineRows.isEmpty) medicineRows.add(_MedicineControllers());
  }

  @override
  void dispose() {
    for (final controller in [
      patient,
      diagnosis,
      age,
      weight,
      notes,
      advice,
      dietAdvice,
      lifestyleAdvice,
      followUpInstructions,
    ]) {
      controller.dispose();
    }
    for (final row in medicineRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(prescriptionPatientsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: key,
        child: ListView(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  widget.prescription == null
                      ? 'Add Prescription'
                      : 'Edit Prescription',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            patients.when(
              loading: () =>
                  const LinearProgressIndicator(color: AppColors.primary),
              error: (_, _) => const SizedBox.shrink(),
              data: (rows) {
                final selected = rows.any((item) => item.id == patientId)
                    ? patientId
                    : null;
                if (rows.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: _fieldDecoration('Select existing patient'),
                    items: rows
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.name} (${item.phone})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      final selectedPatient = rows.firstWhere(
                        (item) => item.id == id,
                      );
                      setState(() {
                        patientId = selectedPatient.id;
                        patient.text = selectedPatient.name;
                        if (selectedPatient.age != null) {
                          age.text = '${selectedPatient.age}';
                        }
                      });
                    },
                  ),
                );
              },
            ),
            TextFormField(
              controller: patient,
              decoration: _fieldDecoration('Patient name *'),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Patient name is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Prescription date',
                    value: date,
                    onChanged: (value) => setState(() => date = value),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: age,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration('Age'),
                    validator: _validateAge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _fieldDecoration('Weight (kg)'),
              validator: _validateWeight,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: diagnosis,
              decoration: _fieldDecoration('Diagnosis'),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Icon(
                  Icons.medication_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Medicines',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () =>
                      setState(() => medicineRows.add(_MedicineControllers())),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add medicine'),
                ),
              ],
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Use the same medicine details shown on the web prescription.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...medicineRows.indexed.map(
              (entry) => _MedicineEditor(
                index: entry.$1,
                controllers: entry.$2,
                canRemove: medicineRows.length > 1,
                onRemove: () =>
                    setState(() => medicineRows.removeAt(entry.$1).dispose()),
              ),
            ),
            TextFormField(
              controller: advice,
              maxLines: 2,
              decoration: _fieldDecoration('General advice'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: dietAdvice,
              maxLines: 2,
              decoration: _fieldDecoration('Diet advice'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: lifestyleAdvice,
              maxLines: 2,
              decoration: _fieldDecoration('Lifestyle advice'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _OptionalDateField(
              label: 'Follow-up date',
              value: followUpDate,
              onChanged: (value) => setState(() => followUpDate = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: followUpInstructions,
              maxLines: 2,
              decoration: _fieldDecoration('Follow-up instructions'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: notes,
              maxLines: 2,
              decoration: _fieldDecoration('Internal notes'),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: saving ? null : _save,
                child: Text(saving ? 'Saving...' : 'Save prescription'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateAge(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = int.tryParse(value);
    return parsed == null || parsed < 0 || parsed > 120
        ? 'Enter an age from 0 to 120'
        : null;
  }

  String? _validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value);
    return parsed == null || parsed < 0 ? 'Enter a valid weight' : null;
  }

  Future<void> _save() async {
    if (!(key.currentState?.validate() ?? false)) return;
    final medicines = medicineRows
        .map((row) => row.item)
        .where((item) => item.name.trim().isNotEmpty)
        .toList();
    if (medicines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one medicine.')),
      );
      return;
    }
    setState(() => saving = true);
    final draft = PrescriptionDraft(
      patientId: patientId,
      patientName: patient.text.trim(),
      diagnosis: _empty(diagnosis.text),
      medicines: medicines,
      notes: _empty(notes.text),
      date: date,
      patientAge: int.tryParse(age.text),
      patientWeight: double.tryParse(weight.text),
      advice: _empty(advice.text),
      dietAdvice: _empty(dietAdvice.text),
      lifestyleAdvice: _empty(lifestyleAdvice.text),
      followUpDate: followUpDate,
      followUpInstructions: _empty(followUpInstructions.text),
      visitId: visitId,
    );
    final controller = ref.read(prescriptionsProvider.notifier);
    final result = widget.prescription == null
        ? await controller.createResult(draft)
        : await controller.updatePrescription(widget.prescription!.id, draft);
    if (!mounted) return;
    setState(() => saving = false);
    result.fold(
      onSuccess: (value) => Navigator.pop(context, value),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage))),
    );
  }

  static String? _empty(String value) =>
      value.trim().isEmpty ? null : value.trim();
}

class _MedicineControllers {
  _MedicineControllers({MedicineItem? item})
    : name = TextEditingController(text: item?.name),
      strength = TextEditingController(text: item?.strength),
      frequency = TextEditingController(text: item?.frequency),
      duration = TextEditingController(text: item?.duration),
      timing = TextEditingController(text: item?.timing),
      route = TextEditingController(text: item?.route),
      instructions = TextEditingController(text: item?.instructions);
  factory _MedicineControllers.fromItem(MedicineItem item) =>
      _MedicineControllers(item: item);
  final TextEditingController name;
  final TextEditingController strength;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController timing;
  final TextEditingController route;
  final TextEditingController instructions;
  MedicineItem get item => MedicineItem(
    name: name.text.trim(),
    strength: strength.text.trim(),
    frequency: frequency.text.trim(),
    duration: duration.text.trim(),
    timing: timing.text.trim(),
    route: route.text.trim(),
    instructions: instructions.text.trim(),
  );
  void dispose() {
    for (final value in [
      name,
      strength,
      frequency,
      duration,
      timing,
      route,
      instructions,
    ]) {
      value.dispose();
    }
  }
}

class _MedicineEditor extends StatelessWidget {
  const _MedicineEditor({
    required this.index,
    required this.controllers,
    required this.canRemove,
    required this.onRemove,
  });
  final int index;
  final _MedicineControllers controllers;
  final bool canRemove;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.035),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.primary.withOpacity(0.12)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Medicine ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (canRemove)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.destructive,
                ),
                tooltip: 'Remove medicine',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controllers.name,
          decoration: _fieldDecoration(
            'Medicine name *',
            hintText: 'e.g. Paracetamol',
          ),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Medicine name is required' : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controllers.strength,
                decoration: _fieldDecoration(
                  'Strength / dosage',
                  hintText: 'e.g. 500 mg',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: controllers.frequency,
                decoration: _fieldDecoration(
                  'Frequency',
                  hintText: 'e.g. Twice daily',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controllers.duration,
                decoration: _fieldDecoration(
                  'Duration',
                  hintText: 'e.g. 5 days',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: controllers.timing,
                decoration: _fieldDecoration(
                  'When to take',
                  hintText: 'e.g. After food',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controllers.route,
          decoration: _fieldDecoration('Route', hintText: 'e.g. Oral'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controllers.instructions,
          maxLines: 2,
          decoration: _fieldDecoration(
            'Additional instructions',
            hintText: 'Special directions for the patient',
          ),
        ),
      ],
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => _pick(context),
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: InputDecorator(
      decoration: _fieldDecoration(
        label,
        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
      ),
      child: Text(DateFormat('dd MMM yyyy').format(value)),
    ),
  );
  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: value,
    );
    if (picked != null) onChanged(picked);
  }
}

class _OptionalDateField extends StatelessWidget {
  const _OptionalDateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => _pick(context),
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: InputDecorator(
      decoration: _fieldDecoration(
        label,
        suffixIcon: value == null
            ? const Icon(Icons.calendar_today_rounded, size: 18)
            : IconButton(
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
      ),
      child: Text(
        value == null ? 'Not set' : DateFormat('dd MMM yyyy').format(value!),
      ),
    ),
  );
  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: value ?? DateTime.now(),
    );
    if (picked != null) onChanged(picked);
  }
}
