import 'dart:async';
import 'dart:typed_data';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/patients/domain/entities/medical_record.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';
import 'package:doctylia_app/features/patients/domain/repositories/patient_repository.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabasePatientRepository implements PatientRepository {
  SupabasePatientRepository(this._client);
  final SupabaseClient _client;

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<PageResult<Patient>>> list(
    PageRequest page, {
    String search = '',
    DateTime? registeredDate,
  }) => _guard(() async {
    dynamic rowsQuery = _directoryFilters(
      _client.from('patients').select().eq('doctor_id', _doctorId),
      search,
      registeredDate,
    );
    dynamic countQuery = _directoryFilters(
      _client
          .from('patients')
          .count(CountOption.exact)
          .eq('doctor_id', _doctorId),
      search,
      registeredDate,
    );
    final result = await Future.wait<dynamic>([
      rowsQuery
          .order('last_visit', ascending: false)
          .range(page.offset, page.offset + page.limit - 1),
      countQuery,
    ]);
    final rows = (result[0] as List).cast<Map<String, dynamic>>();
    final count = result[1] as int;
    return PageResult(
      items: rows.map(PatientMapper.fromJson).toList(growable: false),
      hasMore: page.offset + rows.length < count,
      nextOffset: page.offset + rows.length < count
          ? page.offset + page.limit
          : null,
      totalCount: count,
    );
  });

  dynamic _directoryFilters(
    dynamic query,
    String search,
    DateTime? registeredDate,
  ) {
    if (registeredDate != null) {
      final start = DateTime(
        registeredDate.year,
        registeredDate.month,
        registeredDate.day,
      );
      final end = start.add(const Duration(days: 1));
      query = query
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String());
    }
    final term = search.replaceAll(RegExp(r'[,()%_]'), ' ').trim();
    if (term.isNotEmpty) {
      query = query.or('name.ilike.%$term%,phone.ilike.%$term%');
    }
    return query;
  }

  @override
  Future<Result<List<Patient>>> listForExport() => _guard(() async {
    final all = <Patient>[];
    const batchSize = 500;
    var offset = 0;
    while (true) {
      dynamic query = _directoryFilters(
        _client.from('patients').select().eq('doctor_id', _doctorId),
        '',
        null,
      );
      final rows =
          await query
                  .order('last_visit', ascending: false)
                  .range(offset, offset + batchSize - 1)
              as List;
      all.addAll(rows.cast<Map<String, dynamic>>().map(PatientMapper.fromJson));
      if (rows.length < batchSize) break;
      offset += batchSize;
    }
    return all;
  });

  @override
  Future<Result<Patient>> create(PatientDraft draft) => _guard(() async {
    _validatePatient(draft);
    final row = await _client
        .from('patients')
        .insert({'doctor_id': _doctorId, ..._patientJson(draft)})
        .select()
        .single();
    return PatientMapper.fromJson(row);
  });

  @override
  Future<Result<Patient>> update(String id, PatientDraft draft) =>
      _guard(() async {
        _validatePatient(draft);
        final row = await _client
            .from('patients')
            .update(_patientJson(draft))
            .eq('id', id)
            .eq('doctor_id', _doctorId)
            .select()
            .single();
        return PatientMapper.fromJson(row);
      });

  @override
  Future<Result<Patient>> get(String id) => _guard(() async {
    final row = await _client
        .from('patients')
        .select()
        .eq('id', id)
        .eq('doctor_id', _doctorId)
        .maybeSingle();
    if (row == null) throw const NotFoundFailure('Patient not found.');
    return PatientMapper.fromJson(row);
  });

  @override
  Future<Result<void>> delete(String id) => _guard(() async {
    await _client
        .from('patients')
        .delete()
        .eq('id', id)
        .eq('doctor_id', _doctorId);
  });

  @override
  Future<Result<void>> deleteMany(Set<String> ids) => _guard(() async {
    if (ids.isEmpty) return;
    await _client
        .from('patients')
        .delete()
        .inFilter('id', ids.toList(growable: false))
        .eq('doctor_id', _doctorId);
  });

  @override
  Future<Result<MedicalRecordBundle>> getMedicalRecord(String patientId) =>
      _guard(() async {
        final results = await Future.wait<dynamic>([
          _records(patientId, MedicalRecordSection.conditions, 0, 100),
          _records(patientId, MedicalRecordSection.medications, 0, 100),
          _records(patientId, MedicalRecordSection.allergies, 0, 100),
          _records(patientId, MedicalRecordSection.visits, 0, 3),
          _records(patientId, MedicalRecordSection.documents, 0, 3),
          _records(patientId, MedicalRecordSection.reminders, 0, 1),
          _records(patientId, MedicalRecordSection.surgeries, 0, 100),
          _records(patientId, MedicalRecordSection.familyHistory, 0, 100),
          _records(patientId, MedicalRecordSection.vitals, 0, 10),
        ]);
        final conditions = _items(results[0], MedicalRecordSection.conditions);
        final medications = _items(
          results[1],
          MedicalRecordSection.medications,
        );
        final allergies = _items(results[2], MedicalRecordSection.allergies);
        final visits = _items(results[3], MedicalRecordSection.visits);
        final documents = _items(results[4], MedicalRecordSection.documents);
        final reminders = _items(results[5], MedicalRecordSection.reminders);
        return MedicalRecordBundle(
          conditions: conditions
              .map(
                (item) => MedicalCondition(
                  item.values['condition_name'] as String,
                  item.values['status'] as String,
                  diagnosedOn: _optionalDate(item.values['diagnosis_date']),
                  notes: item.values['notes'] as String?,
                ),
              )
              .toList(),
          medications: medications
              .map(
                (item) => PatientMedication(
                  item.values['medicine_name'] as String,
                  dosage: item.values['dosage'] as String?,
                  frequency: item.values['frequency'] as String?,
                  status: item.values['status'] as String,
                ),
              )
              .toList(),
          allergies: allergies
              .map(
                (item) => PatientAllergy(
                  item.values['allergy_name'] as String,
                  item.values['severity'] as String,
                  reaction: item.values['reaction'] as String?,
                ),
              )
              .toList(),
          visits: visits
              .map(
                (item) => PatientVisit(
                  item.id,
                  DateTime.parse(item.values['visit_date'] as String),
                  reason: item.values['reason_for_visit'] as String?,
                  diagnosis: item.values['diagnosis'] as String?,
                  notes: item.values['doctor_notes'] as String?,
                ),
              )
              .toList(),
          documents: documents
              .map(
                (item) => MedicalDocument(
                  item.id,
                  item.values['document_name'] as String,
                  item.values['document_type'] as String,
                  DateTime.parse(item.values['document_date'] as String),
                ),
              )
              .toList(),
          reminders: reminders
              .map(
                (item) => CheckupReminder(
                  item.id,
                  DateTime.parse(item.values['next_checkup_date'] as String),
                  item.values['frequency'] as String,
                  item.values['status'] as String,
                ),
              )
              .toList(),
          surgeries: _items(results[6], MedicalRecordSection.surgeries),
          familyHistory: _items(results[7], MedicalRecordSection.familyHistory),
          vitals: _items(results[8], MedicalRecordSection.vitals),
        );
      });

  @override
  Future<Result<PageResult<MedicalRecordItem>>> listMedicalRecords(
    String patientId,
    MedicalRecordSection section,
    PageRequest page,
  ) => _guard(() async {
    final result = await Future.wait<dynamic>([
      _records(patientId, section, page.offset, page.limit),
      _recordCount(patientId, section),
    ]);
    final items = _items(result[0], section);
    final count = result[1] as int;
    return PageResult(
      items: items,
      hasMore: page.offset + items.length < count,
      nextOffset: page.offset + items.length < count
          ? page.offset + page.limit
          : null,
      totalCount: count,
    );
  });

  Future<dynamic> _records(
    String patientId,
    MedicalRecordSection section,
    int offset,
    int limit,
  ) async {
    dynamic query = _recordFilters(
      _client
          .from(_table(section))
          .select()
          .eq('patient_id', patientId)
          .eq('doctor_id', _doctorId),
      section,
    );
    final rows =
        await query
                .order(_orderColumn(section), ascending: false)
                .range(offset, offset + limit - 1)
            as List;
    if (section == MedicalRecordSection.visits && rows.isNotEmpty) {
      final ids = rows.map((row) => row['id'] as String).toList();
      final vitals = await _client
          .from('patient_vitals')
          .select()
          .eq('patient_id', patientId)
          .eq('doctor_id', _doctorId)
          .inFilter('visit_id', ids);
      final byVisit = {
        for (final vital in vitals) vital['visit_id'] as String: vital,
      };
      return rows
          .map(
            (row) => <String, dynamic>{
              ...(row as Map<String, dynamic>),
              if (byVisit[row['id']] != null) '_vitals': byVisit[row['id']],
            },
          )
          .toList();
    }
    return rows;
  }

  Future<int> _recordCount(
    String patientId,
    MedicalRecordSection section,
  ) async {
    dynamic query = _recordFilters(
      _client
          .from(_table(section))
          .count(CountOption.exact)
          .eq('patient_id', patientId)
          .eq('doctor_id', _doctorId),
      section,
    );
    return await query as int;
  }

  dynamic _recordFilters(dynamic query, MedicalRecordSection section) {
    if (_softDeleted(section)) query = query.isFilter('deleted_at', null);
    if (section == MedicalRecordSection.reminders) {
      query = query.neq('status', 'cancelled');
    }
    return query;
  }

  @override
  Future<Result<void>> saveMedicalRecord(
    String patientId,
    MedicalRecordSection section,
    Map<String, dynamic> values, {
    String? id,
  }) => _guard(() async {
    if (section == MedicalRecordSection.documents) {
      throw const ValidationFailure('Use document upload to add a file.');
    }
    final source = Map<String, dynamic>.from(values);
    final vitals = section == MedicalRecordSection.visits
        ? source.remove('_vitals') as Map<String, dynamic>?
        : null;
    final payload = <String, dynamic>{
      ...source,
      if (section == MedicalRecordSection.reminders)
        'next_reminder_at': _nextReminderAt(values),
    };
    String? savedId = id;
    if (id == null) {
      final insert = _client.from(_table(section)).insert({
        ...payload,
        'patient_id': patientId,
        'doctor_id': _doctorId,
        'created_by': _doctorId,
        if (section != MedicalRecordSection.vitals) 'updated_by': _doctorId,
      });
      if (section == MedicalRecordSection.visits) {
        final row = await insert.select('id').single();
        savedId = row['id'] as String;
      } else {
        await insert;
      }
    } else {
      await _client
          .from(_table(section))
          .update({
            ...payload,
            if (section != MedicalRecordSection.vitals) 'updated_by': _doctorId,
          })
          .eq('id', id)
          .eq('doctor_id', _doctorId);
    }
    if (section == MedicalRecordSection.visits &&
        savedId != null &&
        vitals != null &&
        vitals.values.any((value) => value != null && value != '')) {
      final existing = await _client
          .from('patient_vitals')
          .select('id')
          .eq('visit_id', savedId)
          .maybeSingle();
      final clean = Map<String, dynamic>.from(vitals)
        ..removeWhere((_, value) => value == '');
      if (existing == null) {
        await _client.from('patient_vitals').insert({
          ...clean,
          'visit_id': savedId,
          'patient_id': patientId,
          'doctor_id': _doctorId,
          'created_by': _doctorId,
        });
      } else {
        await _client
            .from('patient_vitals')
            .update(clean)
            .eq('id', existing['id']);
      }
    }
  });

  @override
  Future<Result<void>> removeMedicalRecord(
    MedicalRecordSection section,
    String id,
  ) => _guard(() async {
    if (section == MedicalRecordSection.reminders) {
      await _client
          .from(_table(section))
          .delete()
          .eq('id', id)
          .eq('doctor_id', _doctorId);
    } else if (_softDeleted(section)) {
      await _client
          .from(_table(section))
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .eq('doctor_id', _doctorId);
    } else {
      await _client
          .from(_table(section))
          .delete()
          .eq('id', id)
          .eq('doctor_id', _doctorId);
    }
  });

  @override
  Future<Result<void>> uploadDocument(
    String patientId,
    MedicalDocumentUpload document,
  ) => _guard(() async {
    final extension = document.fileName.contains('.')
        ? document.fileName.split('.').last.toLowerCase()
        : 'bin';
    if (!{'pdf', 'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw const ValidationFailure(
        'Only PDF, JPG, JPEG, PNG or WebP files are supported.',
      );
    }
    final path =
        '$_doctorId/$patientId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from('patient-documents')
        .uploadBinary(
          path,
          Uint8List.fromList(document.bytes),
          fileOptions: FileOptions(
            contentType: document.mimeType,
            upsert: false,
          ),
        );
    try {
      await _client.from('patient_documents').insert({
        'patient_id': patientId,
        'doctor_id': _doctorId,
        'created_by': _doctorId,
        'document_name': document.name,
        'document_type': document.type,
        'file_path': path,
        'file_type': document.mimeType,
        'document_date': _date(document.date),
        'notes': _emptyToNull(document.notes),
        'visit_id': _emptyToNull(document.visitId),
      });
    } catch (_) {
      await _client.storage.from('patient-documents').remove([path]);
      rethrow;
    }
  });

  @override
  Future<Result<Uri>> getDocumentUrl(String path) => _guard(() async {
    final url = await _client.storage
        .from('patient-documents')
        .createSignedUrl(path, 300);
    return Uri.parse(url);
  });

  @override
  Stream<void> watchChanges() {
    late RealtimeChannel channel;
    late StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('mobile-patients-$_doctorId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'patients',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'doctor_id',
                value: _doctorId,
              ),
              callback: (_) => controller.add(null),
            )
            .subscribe();
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }

  Map<String, dynamic> _patientJson(PatientDraft draft) => {
    'name': draft.name.trim(),
    'phone': _normalizePhone(draft.phone),
    'email': _emptyToNull(draft.email),
    'age': draft.age,
    'gender': draft.gender?.toLowerCase(),
    'notes': _emptyToNull(draft.notes),
  };

  void _validatePatient(PatientDraft draft) {
    if (draft.name.trim().isEmpty) {
      throw const ValidationFailure('Patient name is required.');
    }
    final digits = draft.phone.replaceAll(RegExp(r'\D'), '');
    if (!(digits.length == 10 ||
        (digits.length == 12 && digits.startsWith('91')))) {
      throw const ValidationFailure(
        'Enter a valid 10-digit Indian phone number.',
      );
    }
    if (draft.age != null && (draft.age! < 0 || draft.age! > 120)) {
      throw const ValidationFailure('Age must be between 0 and 120.');
    }
  }

  Future<Result<T>> _guard<T>(Future<T> Function() operation) =>
      RepositoryGuard.run(() async {
        try {
          return await operation();
        } catch (error, stackTrace) {
          if (error is AppFailure) rethrow;
          final text = error.toString().toLowerCase();
          if (error is TimeoutException ||
              text.contains('socketexception') ||
              text.contains('failed host lookup')) {
            throw NetworkFailure(cause: error, stackTrace: stackTrace);
          }
          if (error is PostgrestException && error.code == '42501') {
            throw const PermissionFailure();
          }
          throw ServerFailure(cause: error, stackTrace: stackTrace);
        }
      });

  static List<MedicalRecordItem> _items(
    Object? rows,
    MedicalRecordSection section,
  ) => (rows as List)
      .cast<Map<String, dynamic>>()
      .map(
        (row) => MedicalRecordItem(
          id: row['id'] as String,
          section: section,
          values: Map.unmodifiable(row),
        ),
      )
      .toList(growable: false);

  static String _table(MedicalRecordSection value) => switch (value) {
    MedicalRecordSection.conditions => 'patient_conditions',
    MedicalRecordSection.surgeries => 'patient_surgeries',
    MedicalRecordSection.familyHistory => 'patient_family_history',
    MedicalRecordSection.medications => 'patient_medications',
    MedicalRecordSection.allergies => 'patient_allergies',
    MedicalRecordSection.visits => 'patient_visits',
    MedicalRecordSection.documents => 'patient_documents',
    MedicalRecordSection.vitals => 'patient_vitals',
    MedicalRecordSection.reminders => 'patient_checkup_reminders',
  };

  static String _orderColumn(MedicalRecordSection value) => switch (value) {
    MedicalRecordSection.conditions => 'diagnosis_date',
    MedicalRecordSection.surgeries => 'event_date',
    MedicalRecordSection.familyHistory => 'created_at',
    MedicalRecordSection.medications => 'start_date',
    MedicalRecordSection.allergies => 'created_at',
    MedicalRecordSection.visits => 'visit_date',
    MedicalRecordSection.documents => 'document_date',
    MedicalRecordSection.vitals => 'recorded_date',
    MedicalRecordSection.reminders => 'created_at',
  };

  static bool _softDeleted(MedicalRecordSection value) => switch (value) {
    MedicalRecordSection.conditions ||
    MedicalRecordSection.surgeries ||
    MedicalRecordSection.familyHistory ||
    MedicalRecordSection.medications ||
    MedicalRecordSection.allergies ||
    MedicalRecordSection.visits ||
    MedicalRecordSection.documents => true,
    MedicalRecordSection.vitals || MedicalRecordSection.reminders => false,
  };

  static String _nextReminderAt(Map<String, dynamic> values) {
    final checkup = DateTime.parse(values['next_checkup_date'] as String);
    final before = (values['reminder_before_days'] as num?)?.toInt() ?? 0;
    return checkup.subtract(Duration(days: before)).toUtc().toIso8601String();
  }

  static String _date(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
  static DateTime? _optionalDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
  static String? _emptyToNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '91$digits';
    return '+$digits';
  }
}

abstract final class PatientMapper {
  static Patient fromJson(Map<String, dynamic> row) => Patient(
    id: row['id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String,
    email: row['email'] as String?,
    age: (row['age'] as num?)?.toInt(),
    gender: row['gender'] as String?,
    firstVisit: _date(row['first_visit']),
    lastVisit: _date(row['last_visit']),
    createdAt: _date(row['created_at']),
    totalVisits: (row['total_visits'] as num?)?.toInt() ?? 0,
    notes: row['notes'] as String?,
  );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
