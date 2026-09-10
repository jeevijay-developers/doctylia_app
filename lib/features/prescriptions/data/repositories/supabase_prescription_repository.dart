import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/domain/repositories/prescription_repository.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabasePrescriptionRepository implements PrescriptionRepository {
  SupabasePrescriptionRepository(this._client);
  final SupabaseClient _client;

  String get _doctorId {
    final value = _client.auth.currentUser?.id;
    if (value == null) throw const SessionExpiredFailure();
    return value;
  }

  @override
  Future<Result<PageResult<Prescription>>> list(
    PageRequest page, {
    String search = '',
    DateTime? date,
  }) => _guard(() async {
    final term = search.replaceAll(RegExp(r'[,()%_]'), ' ').trim();
    dynamic rowsQuery = _client
        .from('prescriptions')
        .select()
        .eq('doctor_id', _doctorId);
    dynamic countQuery = _client
        .from('prescriptions')
        .count(CountOption.exact)
        .eq('doctor_id', _doctorId);
    if (date != null) {
      final dateText = DateFormat('yyyy-MM-dd').format(date);
      rowsQuery = rowsQuery.eq('date', dateText);
      countQuery = countQuery.eq('date', dateText);
    }
    if (term.isNotEmpty) {
      final filter = 'patient_name.ilike.%$term%,diagnosis.ilike.%$term%';
      rowsQuery = rowsQuery.or(filter);
      countQuery = countQuery.or(filter);
    }
    final result = await Future.wait<dynamic>([
      rowsQuery
          .order('date', ascending: false)
          .range(page.offset, page.offset + page.limit - 1),
      countQuery,
    ]);
    final rows = (result[0] as List).cast<Map<String, dynamic>>();
    final total = result[1] as int;
    return PageResult(
      items: rows.map(_fromJson).toList(growable: false),
      hasMore: page.offset + rows.length < total,
      nextOffset: page.offset + rows.length < total
          ? page.offset + page.limit
          : null,
      totalCount: total,
    );
  });

  @override
  Future<Result<Prescription>> create(PrescriptionDraft draft) =>
      _guard(() async {
        _validate(draft);
        final row = await _client
            .from('prescriptions')
            .insert({'doctor_id': _doctorId, ..._draftJson(draft)})
            .select()
            .single();
        return _fromJson(row);
      });

  @override
  Future<Result<Prescription>> update(String id, PrescriptionDraft draft) =>
      _guard(() async {
        _validate(draft);
        final row = await _client
            .from('prescriptions')
            .update(_draftJson(draft))
            .eq('id', id)
            .eq('doctor_id', _doctorId)
            .select()
            .single();
        return _fromJson(row);
      });

  @override
  Future<Result<List<PrescriptionPatient>>> listPatients() => _guard(() async {
    final rows = await _client
        .from('patients')
        .select('id,name,phone,gender,age')
        .eq('doctor_id', _doctorId)
        .gt('total_visits', 0)
        .order('name');
    return rows
        .map(
          (row) => PrescriptionPatient(
            id: row['id'] as String,
            name: row['name'] as String,
            phone: row['phone'] as String,
            gender: row['gender'] as String?,
            age: (row['age'] as num?)?.toInt(),
          ),
        )
        .toList(growable: false);
  });

  @override
  Future<Result<PrescriptionSlipDetails>> getSlipDetails(
    Prescription prescription,
  ) => _guard(() async {
    String? gender;
    String? reason;
    String? symptoms;
    var vitals = <String, dynamic>{};
    if (prescription.patientId != null) {
      final patient = await _client
          .from('patients')
          .select('gender')
          .eq('id', prescription.patientId!)
          .eq('doctor_id', _doctorId)
          .maybeSingle();
      gender = patient?['gender'] as String?;
    }
    if (prescription.visitId != null) {
      final result = await Future.wait<dynamic>([
        _client
            .from('patient_visits')
            .select('reason_for_visit,symptoms')
            .eq('id', prescription.visitId!)
            .eq('doctor_id', _doctorId)
            .maybeSingle(),
        _client
            .from('patient_vitals')
            .select(
              'blood_pressure,pulse,temperature,respiratory_rate,spo2,height,weight,bmi',
            )
            .eq('visit_id', prescription.visitId!)
            .eq('doctor_id', _doctorId)
            .order('recorded_date', ascending: false)
            .limit(1)
            .maybeSingle(),
      ]);
      final visit = result[0] as Map<String, dynamic>?;
      reason = visit?['reason_for_visit'] as String?;
      symptoms = visit?['symptoms'] as String?;
      vitals = result[1] as Map<String, dynamic>? ?? {};
    }
    return PrescriptionSlipDetails(
      patientGender: gender,
      visitReason: reason,
      symptoms: symptoms,
      vitals: Map.unmodifiable(vitals),
    );
  });

  @override
  Future<Result<void>> delete(String id) => _guard(() async {
    await _client
        .from('prescriptions')
        .delete()
        .eq('id', id)
        .eq('doctor_id', _doctorId);
  });

  @override
  Future<Result<void>> deleteMany(Set<String> ids) => _guard(() async {
    if (ids.isEmpty) return;
    await _client
        .from('prescriptions')
        .delete()
        .inFilter('id', ids.toList(growable: false))
        .eq('doctor_id', _doctorId);
  });

  @override
  Stream<void> watchChanges() {
    final controller = StreamController<void>();
    final channel = _client
        .channel('mobile-prescriptions-$_doctorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'prescriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'doctor_id',
            value: _doctorId,
          ),
          callback: (_) => controller.add(null),
        )
        .subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Stream<void> watchPatientChanges() {
    final controller = StreamController<void>();
    final channel = _client
        .channel('mobile-prescription-patients-$_doctorId')
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
    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }

  Map<String, dynamic> _draftJson(PrescriptionDraft draft) => {
    'patient_id': _empty(draft.patientId),
    'patient_name': draft.patientName.trim(),
    'diagnosis': _empty(draft.diagnosis),
    'medicines': draft.medicines.map((item) => item.toJson()).toList(),
    'medications': null,
    'notes': _empty(draft.notes),
    'date': DateFormat('yyyy-MM-dd').format(draft.date),
    'patient_age': draft.patientAge,
    'patient_weight': draft.patientWeight,
    'advice': _empty(draft.advice),
    'diet_advice': _empty(draft.dietAdvice),
    'lifestyle_advice': _empty(draft.lifestyleAdvice),
    'follow_up_date': draft.followUpDate == null
        ? null
        : DateFormat('yyyy-MM-dd').format(draft.followUpDate!),
    'follow_up_instructions': _empty(draft.followUpInstructions),
    'visit_id': _empty(draft.visitId),
  };

  static Prescription _fromJson(Map<String, dynamic> row) {
    final raw = row['medicines'];
    final medicines = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (value) =>
                    MedicineItem.fromJson(Map<String, dynamic>.from(value)),
              )
              .where((item) => item.name.trim().isNotEmpty)
              .toList(growable: false)
        : const <MedicineItem>[];
    return Prescription(
      id: row['id'] as String,
      patientId: row['patient_id'] as String?,
      patientName: row['patient_name'] as String,
      diagnosis: row['diagnosis'] as String?,
      medicines: medicines,
      legacyMedications: row['medications'] as String?,
      notes: row['notes'] as String?,
      date: DateTime.parse(row['date'] as String),
      patientAge: (row['patient_age'] as num?)?.toInt(),
      patientWeight: (row['patient_weight'] as num?)?.toDouble(),
      advice: row['advice'] as String?,
      dietAdvice: row['diet_advice'] as String?,
      lifestyleAdvice: row['lifestyle_advice'] as String?,
      followUpDate: _date(row['follow_up_date']),
      followUpInstructions: row['follow_up_instructions'] as String?,
      visitId: row['visit_id'] as String?,
    );
  }

  static void _validate(PrescriptionDraft draft) {
    if (draft.patientName.trim().isEmpty) {
      throw const ValidationFailure('Patient name is required.');
    }
    if (draft.medicines.isEmpty ||
        draft.medicines.every((item) => item.name.trim().isEmpty)) {
      throw const ValidationFailure('Add at least one medicine.');
    }
    if (draft.patientAge != null &&
        (draft.patientAge! < 0 || draft.patientAge! > 120)) {
      throw const ValidationFailure('Age must be between 0 and 120.');
    }
    if (draft.patientWeight != null && draft.patientWeight! < 0) {
      throw const ValidationFailure('Weight cannot be negative.');
    }
  }

  Future<Result<T>> _guard<T>(Future<T> Function() operation) =>
      RepositoryGuard.run(() async {
        try {
          return await operation();
        } catch (error, stackTrace) {
          if (error is AppFailure) rethrow;
          final message = error.toString().toLowerCase();
          if (error is TimeoutException ||
              message.contains('socketexception') ||
              message.contains('failed host lookup')) {
            throw NetworkFailure(cause: error, stackTrace: stackTrace);
          }
          if (error is PostgrestException && error.code == '42501') {
            throw const PermissionFailure();
          }
          throw ServerFailure(cause: error, stackTrace: stackTrace);
        }
      });

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
  static String? _empty(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
