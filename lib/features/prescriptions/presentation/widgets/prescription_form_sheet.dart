import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/presentation/providers/prescription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? hintText,
}) => InputDecoration(
  labelText: label,
  hintText: hintText,
  prefixIcon: prefixIcon,
  suffixIcon: suffixIcon,
  filled: true,
  fillColor: AppColors.primary.withValues(alpha: 0.035),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide.none,
  ),
);

void _toast(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

/// Mirrors the web "Add Prescription" dialog (PrescriptionsPage.tsx):
/// existing patient → name/date → age/weight → diagnosis → structured
/// medicines → Save Prescription.
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
  late DateTime date;
  String? patientId;
  final medicines = <_MedicineFormItem>[];
  bool saving = false;

  bool get _editing => widget.prescription != null;

  @override
  void initState() {
    super.initState();
    final value = widget.prescription;
    patient = TextEditingController(text: value?.patientName);
    diagnosis = TextEditingController(text: value?.diagnosis);
    age = TextEditingController(text: value?.patientAge?.toString());
    weight = TextEditingController(text: _weightText(value?.patientWeight));
    date = value?.date ?? DateTime.now();
    patientId = value?.patientId;
    // Existing medicines are already complete, so start them collapsed.
    medicines.addAll(
      value?.medicines.map(_MedicineFormItem.fromItem) ?? const [],
    );
  }

  @override
  void dispose() {
    for (final controller in [patient, diagnosis, age, weight]) {
      controller.dispose();
    }
    for (final item in medicines) {
      item.dispose();
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
            Text(
              _editing ? 'Edit Prescription' : 'Add Prescription',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            patients.when(
              loading: () =>
                  const LinearProgressIndicator(color: AppColors.primary),
              error: (_, _) => const SizedBox.shrink(),
              data: (rows) {
                if (rows.isEmpty) return const SizedBox.shrink();
                final selected = rows.any((item) => item.id == patientId)
                    ? patientId
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: _fieldDecoration(
                      _editing ? 'Linked Patient' : 'Select Existing Patient',
                      hintText: '-- Or type name below --',
                    ),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: patient,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDecoration(
                      'Patient Name *',
                      prefixIcon: const Icon(Icons.person_outline, size: 18),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Patient name is required'
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _DateField(
                    label: 'Date',
                    value: date,
                    onChanged: (value) => setState(() => date = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: age,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: _fieldDecoration('Age'),
                    validator: _validateAge,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: _fieldDecoration('Weight (kg)'),
                    validator: _validateWeight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: diagnosis,
              decoration: _fieldDecoration(
                'Diagnosis',
                hintText: 'e.g. Acute bronchitis',
                prefixIcon: const Icon(
                  Icons.medical_services_outlined,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Row(
              children: [
                Icon(Icons.medication_rounded, size: 16),
                SizedBox(width: 6),
                Text(
                  'Medicines',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final (index, item) in medicines.indexed)
              Padding(
                key: ObjectKey(item),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MedicineRowEditor(
                  item: item,
                  index: index,
                  onChanged: () => setState(() {}),
                  onRemove: () =>
                      setState(() => medicines.removeAt(index).dispose()),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                onPressed: () =>
                    setState(() => medicines.add(_MedicineFormItem())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Medicine'),
              ),
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
              onPressed: saving ? null : _save,
              child: Text(
                saving
                    ? 'Saving...'
                    : _editing
                    ? 'Save Changes'
                    : 'Save Prescription',
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
        ? 'Please enter a valid age (0–120)'
        : null;
  }

  String? _validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value);
    return parsed == null || parsed < 0 ? 'Weight cannot be negative' : null;
  }

  Future<void> _save() async {
    if (!(key.currentState?.validate() ?? false)) return;
    // Web parity: untouched rows are silently dropped; touched rows must be
    // complete.
    final touched = medicines.where((item) => item.touched).toList();
    for (final item in touched) {
      final error = item.validate();
      if (error != null) {
        _toast(context, error);
        return;
      }
    }
    setState(() => saving = true);
    final existing = widget.prescription;
    final draft = PrescriptionDraft(
      patientId: patientId,
      patientName: patient.text.trim(),
      diagnosis: _empty(diagnosis.text),
      medicines: touched.map((item) => item.toItem()).toList(),
      date: date,
      patientAge: int.tryParse(age.text),
      patientWeight: double.tryParse(weight.text),
      // The web form does not edit these; keep whatever is already stored.
      notes: existing?.notes,
      advice: existing?.advice,
      dietAdvice: existing?.dietAdvice,
      lifestyleAdvice: existing?.lifestyleAdvice,
      followUpDate: existing?.followUpDate,
      followUpInstructions: existing?.followUpInstructions,
      visitId: existing?.visitId,
    );
    final controller = ref.read(prescriptionsProvider.notifier);
    final result = existing == null
        ? await controller.createResult(draft)
        : await controller.updatePrescription(existing.id, draft);
    if (!mounted) return;
    setState(() => saving = false);
    result.fold(
      onSuccess: (value) => Navigator.pop(context, value),
      onFailure: (failure) => _toast(context, failure.userMessage),
    );
  }

  static String? _empty(String value) =>
      value.trim().isEmpty ? null : value.trim();

  static String? _weightText(double? value) {
    if (value == null) return null;
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }
}

/// Form-side mirror of [MedicineItem] (web `MedicineFormItem`). `saved` is
/// UI-only: true collapses the card to its one-line summary.
class _MedicineFormItem {
  _MedicineFormItem({MedicineItem? item, this.saved = false})
    : name = TextEditingController(text: item?.name),
      strength = TextEditingController(text: item?.strength),
      durationDays = TextEditingController(
        text: (item?.durationDays ?? 0) > 0 ? '${item!.durationDays}' : '',
      ),
      morning = item?.morning ?? false,
      afternoon = item?.afternoon ?? false,
      evening = item?.evening ?? false,
      food = item?.food ?? MedicineFood.after;

  factory _MedicineFormItem.fromItem(MedicineItem item) =>
      _MedicineFormItem(item: item, saved: true);

  final TextEditingController name;
  final TextEditingController strength;
  final TextEditingController durationDays;
  bool morning;
  bool afternoon;
  bool evening;
  MedicineFood food;
  bool saved;

  bool get touched =>
      name.text.trim().isNotEmpty ||
      strength.text.trim().isNotEmpty ||
      durationDays.text.trim().isNotEmpty ||
      morning ||
      afternoon ||
      evening;

  String? validate() {
    final label = name.text.trim();
    if (label.isEmpty) return 'Enter a medicine name.';
    if (strength.text.trim().isEmpty) return 'Enter a strength/dose.';
    final days = int.tryParse(durationDays.text.trim()) ?? 0;
    if (days <= 0) return 'Enter a valid duration (in days) for $label.';
    return null;
  }

  MedicineItem toItem() => MedicineItem(
    name: name.text.trim(),
    strength: strength.text.trim(),
    morning: morning,
    afternoon: afternoon,
    evening: evening,
    durationDays: int.tryParse(durationDays.text.trim()) ?? 0,
    food: food,
  );

  void dispose() {
    name.dispose();
    strength.dispose();
    durationDays.dispose();
  }
}

class _MedicineRowEditor extends StatelessWidget {
  const _MedicineRowEditor({
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final _MedicineFormItem item;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(AppRadius.md);
    final decoration = BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: border,
      border: Border.all(color: AppColors.border(context)),
    );
    final removeButton = IconButton(
      onPressed: onRemove,
      tooltip: 'Remove medicine ${index + 1}',
      visualDensity: VisualDensity.compact,
      icon: const Icon(
        Icons.delete_outline_rounded,
        size: 18,
        color: AppColors.destructive,
      ),
    );

    if (item.saved) {
      final value = item.toItem();
      final strength = value.strength.isEmpty ? '' : ' — ${value.strength}';
      return Container(
        decoration: decoration,
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 6, 4, 6),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _edit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${value.name}$strength',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mutedText(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: _edit,
              tooltip: 'Edit medicine ${index + 1}',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            removeButton,
          ],
        ),
      );
    }

    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Medicine ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedText(context),
                  ),
                ),
              ),
              removeButton,
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: item.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration(
                    'Medicine Name *',
                    hintText: 'e.g. Paracetamol',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: TextField(
                  controller: item.strength,
                  decoration: _fieldDecoration(
                    'Strength/Dose *',
                    hintText: 'e.g. 500 mg',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              _TimeOfDayCheck(
                label: 'Morning',
                value: item.morning,
                onChanged: (value) {
                  item.morning = value;
                  onChanged();
                },
              ),
              _TimeOfDayCheck(
                label: 'Afternoon',
                value: item.afternoon,
                onChanged: (value) {
                  item.afternoon = value;
                  onChanged();
                },
              ),
              _TimeOfDayCheck(
                label: 'Evening/Night',
                value: item.evening,
                onChanged: (value) {
                  item.evening = value;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: item.durationDays,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: _fieldDecoration(
                    'Duration (days) *',
                    hintText: 'e.g. 5',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: DropdownButtonFormField<MedicineFood>(
                  initialValue: item.food,
                  isExpanded: true,
                  decoration: _fieldDecoration('Food Instruction *'),
                  items: const [
                    DropdownMenuItem(
                      value: MedicineFood.before,
                      child: Text('Before Food'),
                    ),
                    DropdownMenuItem(
                      value: MedicineFood.after,
                      child: Text('After Food'),
                    ),
                  ],
                  onChanged: (value) {
                    item.food = value ?? MedicineFood.after;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onPressed: () {
                final error = item.validate();
                if (error != null) {
                  _toast(context, error);
                  return;
                }
                item.saved = true;
                onChanged();
              },
              child: const Text('Save Medicine'),
            ),
          ),
        ],
      ),
    );
  }

  void _edit() {
    item.saved = false;
    onChanged();
  }
}

class _TimeOfDayCheck extends StatelessWidget {
  const _TimeOfDayCheck({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onChanged(!value),
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          activeColor: AppColors.primary,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: (checked) => onChanged(checked ?? false),
        ),
        Text(label, style: const TextStyle(fontSize: 12.5)),
        const SizedBox(width: 4),
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
