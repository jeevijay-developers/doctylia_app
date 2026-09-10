import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/prescriptions/data/repositories/mock_prescription_repository.dart';
import 'package:doctylia_app/features/prescriptions/domain/entities/prescription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paginates prescriptions and keeps structured medicines', () async {
    final repo = MockPrescriptionRepository();
    final first = (await repo.list(const PageRequest()) as Success).value;
    expect(first.items, hasLength(20));
    expect(first.hasMore, isTrue);
    expect(first.items.first.medicines.first.name, isNotEmpty);
    final second =
        (await repo.list(const PageRequest(offset: 20)) as Success).value;
    expect(second.items, hasLength(9));
    expect(second.hasMore, isFalse);
  });

  test('creates a searchable prescription', () async {
    final repo = MockPrescriptionRepository();
    await repo.create(
      PrescriptionDraft(
        patientName: 'Unique Patient',
        date: DateTime.now(),
        diagnosis: 'Migraine',
        medicines: const [MedicineItem(name: 'Sumatriptan', dosage: '50 mg')],
      ),
    );
    final result =
        (await repo.list(const PageRequest(), search: 'Unique') as Success)
            .value;
    expect(result.items, hasLength(1));
    expect(result.items.single.medicines.single.name, 'Sumatriptan');
  });

  test('date filter matches the web prescription date query', () async {
    final repo = MockPrescriptionRepository();
    final date = DateTime.now().subtract(const Duration(days: 3));
    final page =
        (await repo.list(const PageRequest(), date: date) as Success).value;

    expect(page.items, hasLength(1));
    expect(page.items.single.id, 'prescription-1');
  });

  test('bulk delete removes only selected prescriptions', () async {
    final repo = MockPrescriptionRepository();
    await repo.deleteMany({'prescription-1', 'prescription-2'});
    final page =
        (await repo.list(const PageRequest(limit: 50)) as Success).value;

    expect(page.totalCount, 27);
    expect(
      page.items.map((prescription) => prescription.id),
      isNot(contains('prescription-1')),
    );
    expect(
      page.items.map((prescription) => prescription.id),
      isNot(contains('prescription-2')),
    );
  });
}
