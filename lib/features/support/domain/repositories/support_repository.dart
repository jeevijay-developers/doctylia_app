import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/support/domain/entities/support_ticket.dart';

abstract interface class SupportRepository {
  Future<Result<PageResult<SupportTicket>>> list(PageRequest page);
  Future<Result<SupportTicket>> create(SupportTicketDraft draft);
  Stream<void> watchChanges();
}
