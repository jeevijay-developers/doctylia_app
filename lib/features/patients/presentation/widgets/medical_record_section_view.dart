import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/theme/app_colors.dart';
import 'package:doctylia_app/core/theme/app_spacing.dart';
import 'package:doctylia_app/features/patients/domain/entities/medical_record.dart';
import 'package:doctylia_app/features/patients/presentation/providers/patient_providers.dart';
import 'package:doctylia_app/core/platform/external_link_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum _FieldKind { text, multiline, date, number, choice, toggle }

class _Field {
  const _Field(
    this.key,
    this.label, {
    this.kind = _FieldKind.text,
    this.required = false,
    this.options = const [],
  });
  final String key;
  final String label;
  final _FieldKind kind;
  final bool required;
  final List<String> options;
}

class _SectionConfig {
  const _SectionConfig({
    required this.title,
    required this.primary,
    required this.fields,
    this.allowAdd = true,
  });
  final String title;
  final String primary;
  final List<_Field> fields;
  final bool allowAdd;
}

const _configs = <MedicalRecordSection, _SectionConfig>{
  MedicalRecordSection.conditions: _SectionConfig(
    title: 'Conditions',
    primary: 'condition_name',
    fields: [
      _Field('condition_name', 'Condition', required: true),
      _Field('diagnosis_date', 'Diagnosis date', kind: _FieldKind.date),
      _Field(
        'treatment_history',
        'Treatment history',
        kind: _FieldKind.multiline,
      ),
      _Field(
        'status',
        'Status',
        kind: _FieldKind.choice,
        options: ['active', 'under_treatment', 'resolved', 'unknown'],
      ),
      _Field('notes', 'Notes', kind: _FieldKind.multiline),
    ],
  ),
  MedicalRecordSection.surgeries: _SectionConfig(
    title: 'Surgeries',
    primary: 'title',
    fields: [
      _Field('title', 'Surgery / procedure', required: true),
      _Field('event_date', 'Date', kind: _FieldKind.date),
      _Field('hospital', 'Hospital'),
      _Field('reason', 'Reason', kind: _FieldKind.multiline),
      _Field('outcome', 'Outcome', kind: _FieldKind.multiline),
      _Field('notes', 'Notes', kind: _FieldKind.multiline),
    ],
  ),
  MedicalRecordSection.familyHistory: _SectionConfig(
    title: 'Family history',
    primary: 'condition',
    fields: [
      _Field('family_member', 'Family member', required: true),
      _Field('relationship', 'Relationship'),
      _Field('condition', 'Condition', required: true),
      _Field('notes', 'Notes', kind: _FieldKind.multiline),
    ],
  ),
  MedicalRecordSection.medications: _SectionConfig(
    title: 'Medications',
    primary: 'medicine_name',
    fields: [
      _Field('medicine_name', 'Medicine', required: true),
      _Field('dosage', 'Dosage'),
      _Field('frequency', 'Frequency'),
      _Field('start_date', 'Start date', kind: _FieldKind.date),
      _Field('end_date', 'End date', kind: _FieldKind.date),
      _Field(
        'status',
        'Status',
        kind: _FieldKind.choice,
        options: ['active', 'completed'],
      ),
      _Field('prescribed_by', 'Prescribed by'),
      _Field('purpose', 'Purpose', kind: _FieldKind.multiline),
    ],
  ),
  MedicalRecordSection.allergies: _SectionConfig(
    title: 'Allergies',
    primary: 'allergy_name',
    fields: [
      _Field('allergy_name', 'Allergy', required: true),
      _Field(
        'allergy_type',
        'Type',
        kind: _FieldKind.choice,
        options: ['drug', 'food', 'other'],
      ),
      _Field(
        'severity',
        'Severity',
        kind: _FieldKind.choice,
        options: ['mild', 'moderate', 'severe'],
      ),
      _Field('reaction', 'Reaction', kind: _FieldKind.multiline),
      _Field('is_active', 'Currently active', kind: _FieldKind.toggle),
      _Field('notes', 'Notes', kind: _FieldKind.multiline),
    ],
  ),
  MedicalRecordSection.visits: _SectionConfig(
    title: 'Visits',
    primary: 'visit_date',
    fields: [
      _Field('visit_date', 'Visit date', kind: _FieldKind.date, required: true),
      _Field('consultation_type', 'Consultation type'),
      _Field(
        'reason_for_visit',
        'Reason for visit',
        kind: _FieldKind.multiline,
      ),
      _Field('symptoms', 'Symptoms', kind: _FieldKind.multiline),
      _Field('diagnosis', 'Diagnosis', kind: _FieldKind.multiline),
      _Field('doctor_notes', 'Doctor notes', kind: _FieldKind.multiline),
      _Field('follow_up_date', 'Follow-up date', kind: _FieldKind.date),
      _Field('_vitals.blood_pressure', 'Blood pressure'),
      _Field('_vitals.pulse', 'Pulse', kind: _FieldKind.number),
      _Field('_vitals.temperature', 'Temperature', kind: _FieldKind.number),
      _Field('_vitals.weight', 'Weight (kg)', kind: _FieldKind.number),
      _Field('_vitals.height', 'Height (cm)', kind: _FieldKind.number),
      _Field('_vitals.spo2', 'SpO2', kind: _FieldKind.number),
      _Field(
        '_vitals.respiratory_rate',
        'Respiratory rate',
        kind: _FieldKind.number,
      ),
      _Field('_vitals.bmi', 'BMI', kind: _FieldKind.number),
    ],
  ),
  MedicalRecordSection.documents: _SectionConfig(
    title: 'Documents',
    primary: 'document_name',
    fields: [
      _Field('document_type', 'Type'),
      _Field('document_date', 'Date'),
      _Field('file_type', 'File type'),
      _Field('notes', 'Notes'),
    ],
  ),
  MedicalRecordSection.vitals: _SectionConfig(
    title: 'Vitals timeline',
    primary: 'recorded_date',
    allowAdd: false,
    fields: [
      _Field('blood_pressure', 'Blood pressure'),
      _Field('pulse', 'Pulse', kind: _FieldKind.number),
      _Field('temperature', 'Temperature', kind: _FieldKind.number),
      _Field('weight', 'Weight (kg)', kind: _FieldKind.number),
      _Field('height', 'Height (cm)', kind: _FieldKind.number),
      _Field('spo2', 'SpO2', kind: _FieldKind.number),
      _Field('respiratory_rate', 'Respiratory rate', kind: _FieldKind.number),
      _Field('bmi', 'BMI', kind: _FieldKind.number),
    ],
  ),
  MedicalRecordSection.reminders: _SectionConfig(
    title: 'Checkup reminders',
    primary: 'next_checkup_date',
    fields: [
      _Field(
        'frequency',
        'Frequency',
        kind: _FieldKind.choice,
        required: true,
        options: [
          'weekly',
          'every_15_days',
          'monthly',
          'every_3_months',
          'every_6_months',
          'yearly',
          'custom',
        ],
      ),
      _Field(
        'custom_interval_days',
        'Custom interval (days)',
        kind: _FieldKind.number,
      ),
      _Field(
        'next_checkup_date',
        'Next checkup date',
        kind: _FieldKind.date,
        required: true,
      ),
      _Field(
        'reminder_before_days',
        'Remind before (days)',
        kind: _FieldKind.number,
      ),
      _Field('whatsapp_enabled', 'WhatsApp reminder', kind: _FieldKind.toggle),
      _Field('sms_enabled', 'SMS reminder', kind: _FieldKind.toggle),
      _Field('in_app_enabled', 'In-app reminder', kind: _FieldKind.toggle),
      _Field(
        'status',
        'Status',
        kind: _FieldKind.choice,
        options: ['active', 'paused', 'completed', 'cancelled'],
      ),
    ],
  ),
};

class MedicalHistoryView extends StatefulWidget {
  const MedicalHistoryView({
    required this.patientId,
    this.readOnly = false,
    super.key,
  });
  final String patientId;
  final bool readOnly;
  @override
  State<MedicalHistoryView> createState() => _MedicalHistoryViewState();
}

class _MedicalHistoryViewState extends State<MedicalHistoryView> {
  MedicalRecordSection section = MedicalRecordSection.conditions;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          0,
        ),
        child: SegmentedButton<MedicalRecordSection>(
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.primary.withOpacity(0.14),
            selectedForegroundColor: AppColors.primary,
          ),
          segments: const [
            ButtonSegment(
              value: MedicalRecordSection.conditions,
              label: Text('Conditions'),
            ),
            ButtonSegment(
              value: MedicalRecordSection.surgeries,
              label: Text('Surgeries'),
            ),
            ButtonSegment(
              value: MedicalRecordSection.familyHistory,
              label: Text('Family'),
            ),
          ],
          selected: {section},
          onSelectionChanged: (value) => setState(() => section = value.first),
        ),
      ),
      Expanded(
        key: ValueKey(section),
        child: MedicalRecordSectionView(
          patientId: widget.patientId,
          section: section,
          readOnly: widget.readOnly,
        ),
      ),
    ],
  );
}

class MedicalRecordSectionView extends ConsumerStatefulWidget {
  const MedicalRecordSectionView({
    required this.patientId,
    required this.section,
    this.readOnly = false,
    super.key,
  });
  final String patientId;
  final MedicalRecordSection section;
  final bool readOnly;
  @override
  ConsumerState<MedicalRecordSectionView> createState() =>
      _MedicalRecordSectionViewState();
}

class _MedicalRecordSectionViewState
    extends ConsumerState<MedicalRecordSectionView> {
  final items = <MedicalRecordItem>[];
  bool loading = true;
  bool loadingMore = false;
  String? error;
  int total = 0;
  int get limit => widget.section == MedicalRecordSection.visits ? 10 : 25;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        loading = true;
        error = null;
      });
    } else {
      setState(() => loadingMore = true);
    }
    final result = await ref
        .read(patientRepositoryProvider)
        .listMedicalRecords(
          widget.patientId,
          widget.section,
          PageRequest(limit: limit, offset: reset ? 0 : items.length),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (page) => setState(() {
        if (reset) items.clear();
        items.addAll(page.items);
        total = page.totalCount ?? page.items.length;
        loading = false;
        loadingMore = false;
      }),
      onFailure: (failure) => setState(() {
        error = failure.userMessage;
        loading = false;
        loadingMore = false;
      }),
    );
  }

  Future<void> _edit([MedicalRecordItem? item]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecordForm(
        patientId: widget.patientId,
        section: widget.section,
        item: item,
      ),
    );
    if (changed == true) await _load(reset: true);
  }

  Future<void> _delete(MedicalRecordItem item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        title: const Text('Delete record?'),
        content: const Text(
          'This record will be removed from the patient history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final result = await ref
        .read(patientRepositoryProvider)
        .removeMedicalRecord(widget.section, item.id);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Record deleted')));
        _load(reset: true);
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _configs[widget.section]!;
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (error != null) {
      return _StateMessage(
        icon: Icons.cloud_off_rounded,
        message: error!,
        action: () => _load(reset: true),
      );
    }
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: items.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: 280,
                      child: _StateMessage(
                        icon: Icons.folder_open_rounded,
                        message: 'No ${config.title.toLowerCase()} added yet.',
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    88,
                  ),
                  itemCount: items.length + (items.length < total ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: loadingMore
                              ? null
                              : () => _load(reset: false),
                          icon: loadingMore
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more_rounded, size: 18),
                          label: Text(loadingMore ? 'Loading…' : 'Load more'),
                        ),
                      );
                    }
                    final item = items[index];
                    return _RecordCard(
                      item: item,
                      config: config,
                      onEdit: widget.readOnly ? null : () => _edit(item),
                      onDelete: widget.readOnly ? null : () => _delete(item),
                      onOpen: widget.section == MedicalRecordSection.documents
                          ? () => _openDocument(item)
                          : null,
                    );
                  },
                ),
        ),
        if (!widget.readOnly &&
            config.allowAdd &&
            !(widget.section == MedicalRecordSection.reminders &&
                items.isNotEmpty))
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: widget.section == MedicalRecordSection.documents
                  ? _uploadDocument
                  : () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                widget.section == MedicalRecordSection.documents
                    ? 'Upload'
                    : 'Add',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openDocument(MedicalRecordItem item) async {
    final path = item.values['file_path']?.toString();
    if (path == null || path.isEmpty) return;
    final result = await ref
        .read(patientRepositoryProvider)
        .getDocumentUrl(path);
    if (!mounted) return;
    result.fold(
      onSuccess: (uri) => ref.read(externalLinkServiceProvider).open(uri),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage))),
    );
  }

  Future<void> _uploadDocument() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (!mounted || picked == null || picked.files.single.bytes == null) return;
    final file = picked.files.single;
    final details = await showDialog<_DocumentDetails>(
      context: context,
      builder: (_) => _DocumentDialog(defaultName: file.name),
    );
    if (details == null || !mounted) return;
    final result = await ref
        .read(patientRepositoryProvider)
        .uploadDocument(
          widget.patientId,
          MedicalDocumentUpload(
            name: details.name,
            type: details.type,
            date: details.date,
            fileName: file.name,
            bytes: file.bytes!,
            notes: details.notes,
          ),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Document uploaded')));
        _load(reset: true);
      },
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage))),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.item,
    required this.config,
    this.onEdit,
    this.onDelete,
    this.onOpen,
  });
  final MedicalRecordItem item;
  final _SectionConfig config;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final values = item.values;
    final title = values[config.primary]?.toString().trim();
    final details = config.fields
        .where((f) => f.key != config.primary && !f.key.startsWith('_vitals.'))
        .map((f) => MapEntry(f.label, values[f.key]))
        .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
        .take(4)
        .map((e) => '${e.key}: ${_pretty(e.value)}')
        .join('\n');
    final isDocument = onOpen != null;
    final accentColor = isDocument ? AppColors.orange : AppColors.primary;

    Widget trailing;
    if (onEdit == null && onDelete == null) {
      trailing = onOpen == null
          ? const SizedBox.shrink()
          : Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: AppColors.onSurface(context).withValues(alpha: 0.35),
            );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.destructive,
              ),
            ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  isDocument
                      ? Icons.description_rounded
                      : Icons.medical_information_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title == null || title.isEmpty
                          ? config.title
                          : _pretty(title),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: AppColors.onSurface(
                            context,
                          ).withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordForm extends ConsumerStatefulWidget {
  const _RecordForm({
    required this.patientId,
    required this.section,
    this.item,
  });
  final String patientId;
  final MedicalRecordSection section;
  final MedicalRecordItem? item;
  @override
  ConsumerState<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends ConsumerState<_RecordForm> {
  final formKey = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  bool saving = false;
  late final _SectionConfig config;

  @override
  void initState() {
    super.initState();
    config = _configs[widget.section]!;
    for (final field in config.fields) {
      dynamic initial;
      if (field.key.startsWith('_vitals.')) {
        initial =
            (widget.item?.values['_vitals'] as Map?)?[field.key
                .split('.')
                .last];
      } else {
        initial = widget.item?.values[field.key];
      }
      if (field.kind == _FieldKind.toggle) {
        values[field.key] = initial ?? false;
      } else if (field.kind == _FieldKind.choice) {
        final candidate = initial?.toString();
        values[field.key] = field.options.contains(candidate)
            ? candidate
            : null;
      } else {
        controllers[field.key] = TextEditingController(
          text: initial?.toString() ?? '',
        );
      }
    }
    if (widget.item == null) {
      if (widget.section == MedicalRecordSection.visits) {
        controllers['visit_date']?.text = DateFormat(
          'yyyy-MM-dd',
        ).format(DateTime.now());
      }
      if (widget.section == MedicalRecordSection.reminders) {
        values['frequency'] = 'every_3_months';
        controllers['reminder_before_days']?.text = '7';
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: AppSpacing.md,
      right: AppSpacing.md,
      top: AppSpacing.sm,
      bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
    ),
    child: Form(
      key: formKey,
      child: ListView(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.item == null
                      ? 'Add ${config.title}'
                      : 'Edit ${config.title}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...config.fields.map(_buildField),
          const SizedBox(height: AppSpacing.sm),
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
              child: Text(saving ? 'Saving…' : 'Save'),
            ),
          ),
        ],
      ),
    ),
  );

  InputDecoration _decoration(String label, {Widget? suffixIcon}) =>
      InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.primary.withOpacity(0.035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      );

  Widget _buildField(_Field field) {
    if (field.kind == _FieldKind.toggle) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.035),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          value: values[field.key] as bool,
          onChanged: (v) => setState(() => values[field.key] = v),
        ),
      );
    }
    if (field.kind == _FieldKind.choice) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DropdownButtonFormField<String>(
          initialValue: values[field.key] as String?,
          decoration: _decoration(field.label),
          items: field.options
              .map((o) => DropdownMenuItem(value: o, child: Text(_pretty(o))))
              .toList(),
          onChanged: (v) => values[field.key] = v,
          validator: (v) =>
              field.required && v == null ? '${field.label} is required' : null,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextFormField(
        controller: controllers[field.key],
        decoration: _decoration(
          field.label,
          suffixIcon: field.kind == _FieldKind.date
              ? const Icon(Icons.calendar_today_rounded, size: 18)
              : null,
        ),
        keyboardType: field.kind == _FieldKind.number
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        maxLines: field.kind == _FieldKind.multiline ? 3 : 1,
        readOnly: field.kind == _FieldKind.date,
        onTap: field.kind == _FieldKind.date ? () => _pickDate(field) : null,
        validator: (v) => field.required && (v == null || v.trim().isEmpty)
            ? '${field.label} is required'
            : null,
      ),
    );
  }

  Future<void> _pickDate(_Field field) async {
    final current =
        DateTime.tryParse(controllers[field.key]!.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: current,
    );
    if (picked != null) {
      controllers[field.key]!.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final payload = <String, dynamic>{};
    final vitals = <String, dynamic>{};
    for (final field in config.fields) {
      dynamic value =
          field.kind == _FieldKind.choice || field.kind == _FieldKind.toggle
          ? values[field.key]
          : controllers[field.key]!.text.trim();
      if (value is String && value.isEmpty) value = null;
      if (field.kind == _FieldKind.number && value != null) {
        value = num.tryParse(value.toString());
      }
      if (field.key.startsWith('_vitals.')) {
        vitals[field.key.split('.').last] = value;
      } else {
        payload[field.key] = value;
      }
    }
    if (vitals.values.any((v) => v != null)) {
      payload['_vitals'] = vitals;
    }
    if (widget.section == MedicalRecordSection.reminders) {
      final before = payload['reminder_before_days'] as num?;
      final interval = payload['custom_interval_days'] as num?;
      if (before != null && before < 0) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder-before days cannot be negative.'),
          ),
        );
        return;
      }
      if (payload['frequency'] == 'custom' &&
          (interval == null || interval <= 0)) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid custom interval.')),
        );
        return;
      }
    }
    if (widget.section == MedicalRecordSection.conditions) {
      payload['status'] ??= 'active';
    }
    if (widget.section == MedicalRecordSection.medications) {
      payload['status'] ??= 'active';
    }
    if (widget.section == MedicalRecordSection.allergies) {
      payload['is_active'] ??= true;
    }
    if (widget.section == MedicalRecordSection.reminders) {
      payload['status'] ??= 'active';
      payload['reminder_before_days'] ??= 1;
    }
    final result = await ref
        .read(patientRepositoryProvider)
        .saveMedicalRecord(
          widget.patientId,
          widget.section,
          payload,
          id: widget.item?.id,
        );
    if (!mounted) return;
    setState(() => saving = false);
    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage))),
    );
  }
}

class _DocumentDetails {
  const _DocumentDetails(this.name, this.type, this.date, this.notes);
  final String name;
  final String type;
  final DateTime date;
  final String? notes;
}

class _DocumentDialog extends StatefulWidget {
  const _DocumentDialog({required this.defaultName});
  final String defaultName;
  @override
  State<_DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<_DocumentDialog> {
  late final name = TextEditingController(
    text: widget.defaultName.replaceFirst(RegExp(r'\.[^.]+$'), ''),
  );
  final notes = TextEditingController();
  String type = 'other';
  DateTime date = DateTime.now();
  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    title: const Text('Document details'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Document name'),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              'lab_report',
              'xray',
              'mri',
              'ct_scan',
              'previous_prescription',
              'other',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => type = v!),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _DocumentDetails(
                  name.text.trim(),
                  type,
                  date,
                  notes.text.trim().isEmpty ? null : notes.text.trim(),
                ),
              ),
        child: const Text('Upload'),
      ),
    ],
  );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.mutedText(context).withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 30, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          if (action != null)
            TextButton(onPressed: action, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String _pretty(Object? value) => value
    .toString()
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
