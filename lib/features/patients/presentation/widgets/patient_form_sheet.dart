import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/appointments/presentation/widgets/appointment_ui.dart';
import 'package:doctylia_app/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';
import 'package:doctylia_app/features/patients/presentation/providers/patient_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

Future<void> showPatientForm(
  BuildContext context,
  WidgetRef ref, {
  Patient? patient,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: appointmentSheetConstraints(context),
  shape: appointmentSheetShape,
  clipBehavior: Clip.antiAlias,
  builder: (_) => DashboardShadcnScope(child: _PatientForm(patient: patient)),
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

  InputDecoration _field(String label, {String? hint, IconData? icon}) =>
      appointmentFieldDecoration(context, label, hint: hint, icon: icon);

  @override
  Widget build(BuildContext context) {
    final isNew = widget.patient == null;
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
                DashboardIconTile(
                  icon: isNew
                      ? Icons.person_add_alt_1_rounded
                      : Icons.manage_accounts_rounded,
                  color: DashboardTokens.teal,
                  size: 42,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNew ? 'Register New Patient' : 'Edit Patient',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        isNew
                            ? 'Clinical intake · fields marked * are required'
                            : 'Update demographics and contact details',
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
          // ── Scrollable section cards ──────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _IntakeSection(
                      step: 1,
                      icon: Icons.badge_outlined,
                      title: 'Personal demographics',
                      subtitle: 'Identity, age and gender',
                      children: [
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: _field(
                            'Full name *',
                            hint: 'e.g. Ananya Sharma',
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Name is required'
                              : null,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _age,
                                keyboardType: TextInputType.number,
                                decoration: _field(
                                  'Age',
                                  hint: 'Years',
                                  icon: Icons.cake_outlined,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gender',
                                    style: TextStyle(
                                      color: AppColors.mutedText(context),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ChoicePills<String>(
                                    options: const ['female', 'male', 'other'],
                                    value: _gender,
                                    labelOf: (value) =>
                                        '${value[0].toUpperCase()}${value.substring(1)}',
                                    onChanged: (value) =>
                                        setState(() => _gender = value),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _IntakeSection(
                      step: 2,
                      icon: Icons.contact_phone_outlined,
                      title: 'Contact details',
                      subtitle: 'How the clinic reaches the patient',
                      children: [
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: appointmentFieldDecoration(
                            context,
                            'Phone *',
                            hint: '10-digit mobile number',
                            prefixText: '+91  ',
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
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _field(
                            'Email',
                            hint: 'name@example.com',
                            icon: Icons.alternate_email_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _IntakeSection(
                      step: 3,
                      icon: Icons.medical_information_outlined,
                      title: 'Medical baseline',
                      subtitle: 'History and notes for the care team',
                      children: [
                        TextFormField(
                          controller: _notes,
                          maxLines: 4,
                          decoration: _field(
                            'Medical notes',
                            hint: 'Past history, ongoing treatment, remarks',
                          ),
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                required maxLength,
                              }) => Text(
                                '$currentLength characters',
                                style: TextStyle(
                                  color: AppColors.subtleText(context),
                                  fontSize: 11,
                                ),
                              ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: DashboardTokens.teal.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(
                              DashboardTokens.innerRadius,
                            ),
                            border: Border.all(
                              color: DashboardTokens.teal.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: DashboardTokens.tealDeep,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Chronic conditions, allergies, medications '
                                  'and vitals are recorded in the patient\'s '
                                  'medical record after registration.',
                                  style: TextStyle(
                                    color: AppColors.mutedText(context),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                                      ? Icons.person_add_alt_1_rounded
                                      : Icons.check_rounded,
                                  size: 18,
                                ),
                          child: Text(
                            _saving
                                ? 'Saving...'
                                : isNew
                                ? 'Save Patient'
                                : 'Update Profile',
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

/// Card-style group of related intake fields with a numbered header.
class _IntakeSection extends StatelessWidget {
  const _IntakeSection({
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
