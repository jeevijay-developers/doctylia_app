import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:doctylia_app/features/support/domain/entities/support_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support enums retain the web database values', () {
    expect(SupportTicketStatus.inProgress.wireValue, 'in_progress');
    expect(SupportCategory.myWebsite.wireValue, 'my-website');
    expect(SupportPriority.normal.wireValue, 'normal');
  });

  test('support tickets paginate with reply metadata', () async {
    final repo = MockSupportRepository();
    final first = (await repo.list(const PageRequest()) as Success).value;
    expect(first.items, hasLength(20));
    expect(first.hasMore, isTrue);
    expect(first.items.where((ticket) => ticket.reply != null), isNotEmpty);
  });

  test('creates an open support request using the web categories', () async {
    final repo = MockSupportRepository();
    final result = await repo.create(
      const SupportTicketDraft(
        subject: 'Need billing help',
        description: 'Please help with an invoice.',
        priority: SupportPriority.high,
        category: SupportCategory.billing,
      ),
    );
    expect(result, isA<Success<SupportTicket>>());
    final ticket = (result as Success<SupportTicket>).value;
    expect(ticket.status, SupportTicketStatus.open);
    expect(ticket.category, SupportCategory.billing);
  });

  test('rejects a blank support subject', () async {
    final repo = MockSupportRepository();
    final result = await repo.create(
      const SupportTicketDraft(
        subject: '   ',
        description: '',
        priority: SupportPriority.normal,
        category: SupportCategory.other,
      ),
    );
    expect(result, isA<Failure>());
  });

  test('rejects a blank support message', () async {
    final repo = MockSupportRepository();
    final result = await repo.create(
      const SupportTicketDraft(
        subject: 'Need help',
        description: '   ',
        priority: SupportPriority.normal,
        category: SupportCategory.other,
      ),
    );
    expect(result, isA<Failure>());
  });
}
