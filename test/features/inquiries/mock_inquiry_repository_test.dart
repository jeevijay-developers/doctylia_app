import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/inquiries/data/repositories/mock_inquiry_repository.dart';
import 'package:doctylia_app/features/inquiries/domain/entities/patient_inquiry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inquiries paginate and filter by status', () async {
    final repo = MockInquiryRepository();
    final first = (await repo.list(const PageRequest()) as Success).value;
    expect(first.items, hasLength(20));
    expect(first.hasMore, isTrue);
    final fresh =
        (await repo.list(const PageRequest(), status: InquiryStatus.newMessage)
                as Success)
            .value;
    expect(
      fresh.items,
      everyElement(
        predicate<PatientInquiry>(
          (row) => row.status == InquiryStatus.newMessage,
        ),
      ),
    );
  });
  test('inquiry status updates stats', () async {
    final repo = MockInquiryRepository();
    final first = (await repo.list(const PageRequest()) as Success).value;
    final row = first.items.first as PatientInquiry;
    final before = (await repo.getStats() as Success).value as InquiryStats;
    await repo.setStatus(row.id, InquiryStatus.responded);
    final after = (await repo.getStats() as Success).value as InquiryStats;
    expect(after.responded, greaterThanOrEqualTo(before.responded));
  });
}
