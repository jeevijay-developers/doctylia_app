import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/support/domain/entities/support_ticket.dart';
import 'package:doctylia_app/features/support/domain/repositories/support_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseSupportRepository implements SupportRepository {
  SupabaseSupportRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id,doctor_id,subject,description,status,priority,category,reply,replied_at,replied_by,submitted_by_name,submitted_by_user_id,metadata,created_at,updated_at';

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<PageResult<SupportTicket>>> list(PageRequest page) =>
      _guard(() async {
        final doctorId = _doctorId;
        final result = await Future.wait<dynamic>([
          _client
              .from('support_tickets')
              .select(_columns)
              .eq('doctor_id', doctorId)
              .order('created_at', ascending: false)
              .range(page.offset, page.offset + page.limit - 1),
          _client
              .from('support_tickets')
              .count(CountOption.exact)
              .eq('doctor_id', doctorId),
        ]);
        final rows = (result[0] as List).cast<Map<String, dynamic>>();
        final total = result[1] as int;
        final hasMore = page.offset + rows.length < total;
        return PageResult(
          items: rows.map(_fromJson).toList(growable: false),
          hasMore: hasMore,
          nextOffset: hasMore ? page.offset + page.limit : null,
          totalCount: total,
        );
      });

  @override
  Future<Result<SupportTicket>> create(SupportTicketDraft draft) =>
      _guard(() async {
        final subject = draft.subject.trim();
        final description = draft.description.trim();
        if (subject.isEmpty) {
          throw const ValidationFailure('Subject is required.');
        }
        if (description.isEmpty) {
          throw const ValidationFailure('Message is required.');
        }
        final doctorId = _doctorId;
        final profile = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', doctorId)
            .single();
        final row = await _client
            .from('support_tickets')
            .insert({
              'doctor_id': doctorId,
              'submitted_by_user_id': doctorId,
              'submitted_by_name': profile['full_name'] as String? ?? '',
              'subject': subject,
              'description': description,
              'priority': draft.priority.wireValue,
              'category': draft.category.wireValue,
            })
            .select(_columns)
            .single();
        return _fromJson(row);
      });

  @override
  Stream<void> watchChanges() {
    final controller = StreamController<void>();
    final channel = _client
        .channel('mobile-support-$_doctorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_tickets',
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

  static SupportTicket _fromJson(Map<String, dynamic> row) => SupportTicket(
    id: row['id'] as String,
    doctorId: row['doctor_id'] as String,
    subject: row['subject'] as String,
    description: row['description'] as String?,
    status: _status(row['status'] as String),
    priority: _priority(row['priority'] as String),
    category: _category(row['category'] as String?),
    reply: row['reply'] as String?,
    repliedAt: _date(row['replied_at']),
    repliedBy: row['replied_by'] as String?,
    assignedTo: null,
    notes: null,
    submittedByName: row['submitted_by_name'] as String? ?? '',
    submittedByUserId: row['submitted_by_user_id'] as String?,
    metadata: row['metadata'] is Map
        ? Map<String, Object?>.from(row['metadata'] as Map)
        : null,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );

  static SupportTicketStatus _status(String value) =>
      SupportTicketStatus.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => SupportTicketStatus.open,
      );

  static SupportPriority _priority(String value) =>
      SupportPriority.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => SupportPriority.normal,
      );

  static SupportCategory? _category(String? value) {
    if (value == null) return null;
    for (final item in SupportCategory.values) {
      if (item.wireValue == value) return item;
    }
    return null;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

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
          if (error is PostgrestException) {
            if (error.code == '42501') throw const PermissionFailure();
          }
          throw ServerFailure(cause: error, stackTrace: stackTrace);
        }
      });
}
