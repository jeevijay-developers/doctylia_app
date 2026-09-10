import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/inquiries/domain/entities/patient_inquiry.dart';
import 'package:doctylia_app/features/inquiries/domain/repositories/inquiry_repository.dart';

final class MockInquiryRepository implements InquiryRepository {
  MockInquiryRepository() : _items = _seed();
  final List<PatientInquiry> _items;
  @override
  Future<Result<PageResult<PatientInquiry>>> list(
    PageRequest page, {
    String search = '',
    InquiryStatus? status,
  }) => RepositoryGuard.run(() {
    final term = search.trim().toLowerCase();
    final rows =
        _items
            .where(
              (row) =>
                  (term.isEmpty ||
                      row.name.toLowerCase().contains(term) ||
                      row.message.toLowerCase().contains(term)) &&
                  (status == null || row.status == status),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final end = (page.offset + page.limit + 1).clamp(0, rows.length);
    final lookahead = page.offset >= rows.length
        ? <PatientInquiry>[]
        : rows.sublist(page.offset, end);
    return PageResult.fromLookahead(
      rows: lookahead,
      request: page,
      totalCount: rows.length,
    );
  });
  @override
  Future<Result<InquiryStats>> getStats() => RepositoryGuard.run(
    () => InquiryStats(
      total: _items.length,
      newCount: _items
          .where((row) => row.status == InquiryStatus.newMessage)
          .length,
      responded: _items
          .where((row) => row.status == InquiryStatus.responded)
          .length,
    ),
  );
  @override
  Future<Result<void>> setStatus(String id, InquiryStatus status) =>
      RepositoryGuard.run(() {
        final index = _items.indexWhere((row) => row.id == id);
        if (index < 0) throw StateError('Inquiry not found.');
        _items[index] = _items[index].copyWith(status: status);
      });
  @override
  Stream<void> watchChanges() => const Stream.empty();
}

List<PatientInquiry> _seed() {
  final now = DateTime.now();
  const names = ['Ananya Sharma', 'Rohan Mehta', 'Meera Kapoor', 'Kabir Singh'];
  const messages = [
    'I would like to book a consultation for recurring headaches.',
    'Do you offer online appointments this weekend?',
    'Could you share the clinic location and available timings?',
  ];
  return List.generate(
    31,
    (index) => PatientInquiry(
      id: 'inquiry-$index',
      name: names[index % names.length],
      phone: index.isEven ? '+91 98765 43${(100 + index)}' : null,
      email: index.isOdd ? 'patient$index@example.com' : null,
      message: messages[index % messages.length],
      status: InquiryStatus.values[index % 3],
      createdAt: now.subtract(Duration(hours: index * 7)),
    ),
  );
}
