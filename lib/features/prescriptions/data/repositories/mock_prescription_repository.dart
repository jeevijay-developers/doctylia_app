import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:doctylia_app/features/prescriptions/domain/repositories/prescription_repository.dart';

final class MockPrescriptionRepository implements PrescriptionRepository {
  MockPrescriptionRepository() : _items = _seedPrescriptions();
  final List<Prescription> _items;

  @override
  Future<Result<PageResult<Prescription>>> list(
    PageRequest page, {
    String search = '',
    DateTime? date,
  }) => RepositoryGuard.run(() {
    final term = search.trim().toLowerCase();
    final rows =
        _items
            .where(
              (item) =>
                  term.isEmpty ||
                  item.patientName.toLowerCase().contains(term) ||
                  (item.diagnosis ?? '').toLowerCase().contains(term),
            )
            .where(
              (item) =>
                  date == null ||
                  (item.date.year == date.year &&
                      item.date.month == date.month &&
                      item.date.day == date.day),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final end = (page.offset + page.limit + 1).clamp(0, rows.length);
    final result = page.offset >= rows.length
        ? <Prescription>[]
        : rows.sublist(page.offset, end);
    return PageResult.fromLookahead(
      rows: result,
      request: page,
      totalCount: rows.length,
    );
  });

  @override
  Future<Result<Prescription>> create(PrescriptionDraft draft) =>
      RepositoryGuard.run(() {
        final item = _fromDraft(
          id: 'prescription-${DateTime.now().microsecondsSinceEpoch}',
          draft: draft,
        );
        _items.add(item);
        return item;
      });

  @override
  Future<Result<Prescription>> update(String id, PrescriptionDraft draft) =>
      RepositoryGuard.run(() {
        final index = _items.indexWhere((item) => item.id == id);
        if (index < 0) throw StateError('Prescription not found');
        final item = _fromDraft(id: id, draft: draft);
        _items[index] = item;
        return item;
      });

  @override
  Future<Result<List<PrescriptionPatient>>> listPatients() =>
      RepositoryGuard.run(
        () => const [
          PrescriptionPatient(
            id: 'patient-0',
            name: 'Ananya Sharma',
            phone: '+919876543210',
            gender: 'female',
            age: 31,
          ),
          PrescriptionPatient(
            id: 'patient-1',
            name: 'Rohan Mehta',
            phone: '+919812345678',
            gender: 'male',
            age: 39,
          ),
        ],
      );

  @override
  Future<Result<PrescriptionSlipDetails>> getSlipDetails(
    Prescription prescription,
  ) => RepositoryGuard.run(
    () => const PrescriptionSlipDetails(patientGender: 'female'),
  );

  @override
  Future<Result<void>> delete(String id) =>
      RepositoryGuard.run(() => _items.removeWhere((item) => item.id == id));

  @override
  Future<Result<void>> deleteMany(Set<String> ids) => RepositoryGuard.run(
    () => _items.removeWhere((item) => ids.contains(item.id)),
  );

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Stream<void> watchPatientChanges() => const Stream.empty();
}

Prescription _fromDraft({
  required String id,
  required PrescriptionDraft draft,
}) => Prescription(
  id: id,
  patientId: draft.patientId,
  patientName: draft.patientName.trim(),
  diagnosis: draft.diagnosis,
  medicines: draft.medicines,
  notes: draft.notes,
  date: draft.date,
  patientAge: draft.patientAge,
  patientWeight: draft.patientWeight,
  advice: draft.advice,
  dietAdvice: draft.dietAdvice,
  lifestyleAdvice: draft.lifestyleAdvice,
  followUpDate: draft.followUpDate,
  followUpInstructions: draft.followUpInstructions,
  visitId: draft.visitId,
);

List<Prescription> _seedPrescriptions() {
  const names = ['Ananya Sharma', 'Rohan Mehta', 'Meera Kapoor', 'Kabir Singh'];
  return List.generate(
    29,
    (index) => Prescription(
      id: 'prescription-$index',
      patientId: 'patient-${index % 20}',
      patientName: names[index % names.length],
      diagnosis: index.isEven ? 'Viral fever' : 'Hypertension follow-up',
      medicines: [
        MedicineItem(
          name: index.isEven ? 'Paracetamol' : 'Amlodipine',
          strength: index.isEven ? '500 mg' : '5 mg',
          morning: true,
          evening: index.isEven,
          durationDays: 5,
        ),
      ],
      notes: 'Take after food',
      date: DateTime.now().subtract(Duration(days: index * 3)),
      patientAge: 28 + index % 30,
      patientWeight: 55 + index % 25,
    ),
  );
}
