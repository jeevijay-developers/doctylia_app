import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/patients/domain/entities/medical_record.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';
import 'package:doctylia_app/features/patients/domain/repositories/patient_repository.dart';

final class MockPatientRepository implements PatientRepository {
  MockPatientRepository() : _items = _seedPatients();
  final List<Patient> _items;

  @override
  Future<Result<Patient>> create(PatientDraft draft) => RepositoryGuard.run(() {
    final patient = Patient(
      id: 'patient-${DateTime.now().microsecondsSinceEpoch}',
      name: draft.name.trim(),
      phone: draft.phone.trim(),
      email: draft.email,
      age: draft.age,
      gender: draft.gender,
      totalVisits: 0,
      createdAt: DateTime.now(),
      notes: draft.notes,
    );
    _items.add(patient);
    return patient;
  });

  @override
  Future<Result<MedicalRecordBundle>> getMedicalRecord(String patientId) =>
      RepositoryGuard.run(() {
        _items.firstWhere((p) => p.id == patientId);
        final now = DateTime.now();
        return MedicalRecordBundle(
          conditions: [
            MedicalCondition(
              'Hypertension',
              'active',
              diagnosedOn: now.subtract(const Duration(days: 420)),
            ),
          ],
          medications: const [
            PatientMedication(
              'Amlodipine',
              dosage: '5 mg',
              frequency: 'Once daily',
            ),
          ],
          allergies: const [
            PatientAllergy('Penicillin', 'moderate', reaction: 'Skin rash'),
          ],
          visits: [
            PatientVisit(
              'visit-1',
              now.subtract(const Duration(days: 18)),
              reason: 'Follow-up',
              diagnosis: 'Blood pressure review',
            ),
            PatientVisit(
              'visit-2',
              now.subtract(const Duration(days: 90)),
              reason: 'Routine consultation',
            ),
          ],
          documents: [
            MedicalDocument(
              'doc-1',
              'Blood test report',
              'lab_report',
              now.subtract(const Duration(days: 45)),
            ),
          ],
          reminders: [
            CheckupReminder(
              'reminder-1',
              now.add(const Duration(days: 30)),
              'monthly',
              'scheduled',
            ),
          ],
        );
      });

  @override
  Future<Result<PageResult<Patient>>> list(
    PageRequest page, {
    String search = '',
    DateTime? registeredDate,
  }) => RepositoryGuard.run(() {
    final term = search.trim().toLowerCase();
    final rows =
        _items
            .where(
              (p) =>
                  term.isEmpty ||
                  p.name.toLowerCase().contains(term) ||
                  p.phone.contains(term),
            )
            .where(
              (p) =>
                  registeredDate == null ||
                  (p.createdAt?.year == registeredDate.year &&
                      p.createdAt?.month == registeredDate.month &&
                      p.createdAt?.day == registeredDate.day),
            )
            .toList()
          ..sort(
            (a, b) => (b.lastVisit ?? DateTime(2000)).compareTo(
              a.lastVisit ?? DateTime(2000),
            ),
          );
    final end = (page.offset + page.limit + 1).clamp(0, rows.length);
    final result = page.offset >= rows.length
        ? <Patient>[]
        : rows.sublist(page.offset, end);
    return PageResult.fromLookahead(
      rows: result,
      request: page,
      totalCount: rows.length,
    );
  });

  @override
  Future<Result<List<Patient>>> listForExport() =>
      RepositoryGuard.run(() async {
        final result = await list(
          const PageRequest(limit: 100),
          registeredDate: null,
        );
        return result.fold(
          onSuccess: (page) => page.items.toList(),
          onFailure: (failure) => throw failure,
        );
      });

  @override
  Future<Result<Patient>> update(String id, PatientDraft draft) =>
      RepositoryGuard.run(() {
        final index = _items.indexWhere((patient) => patient.id == id);
        final old = _items[index];
        final updated = Patient(
          id: old.id,
          name: draft.name,
          phone: draft.phone,
          email: draft.email,
          age: draft.age,
          gender: draft.gender,
          firstVisit: old.firstVisit,
          lastVisit: old.lastVisit,
          createdAt: old.createdAt,
          totalVisits: old.totalVisits,
          notes: draft.notes,
        );
        _items[index] = updated;
        return updated;
      });

  @override
  Future<Result<PageResult<MedicalRecordItem>>> listMedicalRecords(
    String patientId,
    MedicalRecordSection section,
    PageRequest page,
  ) => RepositoryGuard.run(
    () => PageResult<MedicalRecordItem>(items: const [], hasMore: false),
  );

  @override
  Future<Result<void>> saveMedicalRecord(
    String patientId,
    MedicalRecordSection section,
    Map<String, dynamic> values, {
    String? id,
  }) => RepositoryGuard.run(() {});

  @override
  Future<Result<void>> removeMedicalRecord(
    MedicalRecordSection section,
    String id,
  ) => RepositoryGuard.run(() {});

  @override
  Future<Result<void>> uploadDocument(
    String patientId,
    MedicalDocumentUpload document,
  ) => RepositoryGuard.run(() {});

  @override
  Future<Result<Uri>> getDocumentUrl(String path) =>
      RepositoryGuard.run(() => Uri.parse('https://example.com/$path'));

  @override
  Future<Result<Patient>> get(String id) =>
      RepositoryGuard.run(() => _items.firstWhere((p) => p.id == id));

  @override
  Future<Result<void>> delete(String id) =>
      RepositoryGuard.run(() => _items.removeWhere((p) => p.id == id));

  @override
  Future<Result<void>> deleteMany(Set<String> ids) =>
      RepositoryGuard.run(() => _items.removeWhere((p) => ids.contains(p.id)));

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

List<Patient> _seedPatients() {
  const names = [
    'Ananya Sharma',
    'Rohan Mehta',
    'Meera Kapoor',
    'Kabir Singh',
    'Ishita Rao',
  ];
  final today = DateTime.now();
  return List.generate(
    33,
    (index) => Patient(
      id: 'patient-$index',
      name: names[index % names.length],
      phone: '+91981234${1000 + index}',
      email: 'patient$index@example.com',
      age: 24 + index % 45,
      gender: index.isEven ? 'Female' : 'Male',
      firstVisit: today.subtract(Duration(days: 180 + index)),
      lastVisit: today.subtract(Duration(days: index * 2)),
      createdAt: today.subtract(Duration(days: index)),
      totalVisits: 1 + index % 9,
      notes: index % 4 == 0 ? 'Prefers morning appointments' : null,
    ),
  );
}
