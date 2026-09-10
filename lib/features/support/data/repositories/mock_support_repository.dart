import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/support/domain/entities/support_ticket.dart';
import 'package:doctylia_app/features/support/domain/repositories/support_repository.dart';

final class MockSupportRepository implements SupportRepository {
  MockSupportRepository() : _items = _seedTickets();
  final List<SupportTicket> _items;

  @override
  Future<Result<PageResult<SupportTicket>>> list(PageRequest page) =>
      RepositoryGuard.run(() {
        final rows = [..._items]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final end = (page.offset + page.limit + 1).clamp(0, rows.length);
        final lookahead = page.offset >= rows.length
            ? <SupportTicket>[]
            : rows.sublist(page.offset, end);
        return PageResult.fromLookahead(
          rows: lookahead,
          request: page,
          totalCount: rows.length,
        );
      });

  @override
  Future<Result<SupportTicket>> create(SupportTicketDraft draft) =>
      RepositoryGuard.run(() {
        if (draft.subject.trim().isEmpty) {
          throw const ValidationFailure('Subject is required.');
        }
        if (draft.description.trim().isEmpty) {
          throw const ValidationFailure('Message is required.');
        }
        final now = DateTime.now();
        final ticket = SupportTicket(
          id: 'ticket-${now.microsecondsSinceEpoch}',
          doctorId: 'doctor-1',
          subject: draft.subject.trim(),
          description: draft.description.trim().isEmpty
              ? null
              : draft.description.trim(),
          status: SupportTicketStatus.open,
          priority: draft.priority,
          category: draft.category,
          submittedByName: 'Doctor',
          submittedByUserId: 'doctor-1',
          createdAt: now,
          updatedAt: now,
        );
        _items.add(ticket);
        return ticket;
      });

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

List<SupportTicket> _seedTickets() {
  final now = DateTime.now();
  const subjects = [
    'Need help updating clinic timings',
    'Invoice export question',
    'Staff account access issue',
    'Website booking settings',
  ];
  return List.generate(26, (index) {
    final hasReply = index % 3 != 0;
    return SupportTicket(
      id: 'ticket-$index',
      doctorId: 'doctor-1',
      subject: subjects[index % subjects.length],
      description:
          'Please help me understand the correct steps for this section of my Doctylia account.',
      status: hasReply
          ? (index.isEven
                ? SupportTicketStatus.resolved
                : SupportTicketStatus.inProgress)
          : SupportTicketStatus.open,
      priority: SupportPriority.values[index % SupportPriority.values.length],
      category: SupportCategory.values[index % SupportCategory.values.length],
      reply: hasReply
          ? 'Thanks for contacting Doctylia. We reviewed your request and shared the recommended next step.'
          : null,
      repliedAt: hasReply
          ? now.subtract(Duration(days: index, hours: 2))
          : null,
      repliedBy: hasReply ? 'Doctylia Support' : null,
      submittedByName: 'Doctor',
      submittedByUserId: 'doctor-1',
      createdAt: now.subtract(Duration(days: index * 2)),
      updatedAt: now.subtract(Duration(days: index)),
    );
  });
}
