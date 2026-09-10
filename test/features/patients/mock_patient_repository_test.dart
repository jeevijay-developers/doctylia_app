import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/patients/data/repositories/mock_patient_repository.dart';
import 'package:doctylia_app/features/patients/domain/entities/patient.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paginates and searches patients', () async {
    final repo = MockPatientRepository();
    final first = (await repo.list(const PageRequest()) as Success).value;
    expect(first.items, hasLength(20));
    expect(first.hasMore, isTrue);
    final second =
        (await repo.list(const PageRequest(offset: 20)) as Success).value;
    expect(second.items, hasLength(13));
    expect(second.hasMore, isFalse);
    final search =
        (await repo.list(const PageRequest(), search: 'Ananya') as Success)
            .value;
    expect(
      search.items,
      everyElement(predicate<Patient>((p) => p.name.contains('Ananya'))),
    );
  });

  test(
    'date filter uses registration date like the web patients page',
    () async {
      final repo = MockPatientRepository();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final page =
          (await repo.list(const PageRequest(), registeredDate: yesterday)
                  as Success)
              .value;

      expect(page.items, hasLength(1));
      expect(page.items.single.id, 'patient-1');
      expect(page.items.single.lastVisit?.day, isNot(yesterday.day));
    },
  );

  test('CSV export returns all patients independent of page filters', () async {
    final repo = MockPatientRepository();
    final rows = (await repo.listForExport() as Success).value;
    expect(rows, hasLength(33));
  });

  test('patient status labels match the web visit thresholds', () {
    Patient patient(int visits) => Patient(
      id: '$visits',
      name: 'Patient',
      phone: '+919876543210',
      totalVisits: visits,
    );

    expect(patient(0).statusLabel, 'New');
    expect(patient(2).statusLabel, 'New');
    expect(patient(3).statusLabel, 'Regular');
    expect(patient(9).statusLabel, 'Regular');
    expect(patient(10).statusLabel, 'Loyal');
  });

  test('bulk delete removes only the selected patient records', () async {
    final repo = MockPatientRepository();
    await repo.deleteMany({'patient-1', 'patient-2'});
    final rows = (await repo.listForExport() as Success).value;

    expect(rows, hasLength(31));
    expect(rows.map((patient) => patient.id), isNot(contains('patient-1')));
    expect(rows.map((patient) => patient.id), isNot(contains('patient-2')));
  });

  test('loads typed patient medical record sections', () async {
    final repo = MockPatientRepository();
    final record = (await repo.getMedicalRecord('patient-1') as Success).value;
    expect(record.conditions, isNotEmpty);
    expect(record.medications, isNotEmpty);
    expect(record.allergies, isNotEmpty);
    expect(record.visits, isNotEmpty);
    expect(record.documents, isNotEmpty);
    expect(record.reminders, isNotEmpty);
  });
}
