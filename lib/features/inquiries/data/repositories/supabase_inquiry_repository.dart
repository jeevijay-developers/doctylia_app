import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/pagination/page_request.dart';
import 'package:doctylia_app/core/pagination/page_result.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/inquiries/domain/entities/patient_inquiry.dart';
import 'package:doctylia_app/features/inquiries/domain/repositories/inquiry_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseInquiryRepository implements InquiryRepository {
  SupabaseInquiryRepository(this._client);

  final SupabaseClient _client;

  String get _doctorId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<PageResult<PatientInquiry>>> list(
    PageRequest page, {
    String search = '',
    InquiryStatus? status,
  }) => _guard(() async {
    final term = search.replaceAll(RegExp(r'[,()%_]'), ' ').trim();
    dynamic rowsQuery = _client
        .from('patient_queries')
        .select('id,name,phone,email,message,status,created_at')
        .eq('doctor_id', _doctorId);
    dynamic countQuery = _client
        .from('patient_queries')
        .count(CountOption.exact)
        .eq('doctor_id', _doctorId);

    if (term.isNotEmpty) {
      final filter =
          'name.ilike.%$term%,phone.ilike.%$term%,email.ilike.%$term%,message.ilike.%$term%';
      rowsQuery = rowsQuery.or(filter);
      countQuery = countQuery.or(filter);
    }
    if (status != null) {
      rowsQuery = rowsQuery.eq('status', _statusValue(status));
      countQuery = countQuery.eq('status', _statusValue(status));
    }

    final result = await Future.wait<dynamic>([
      rowsQuery
          .order('created_at', ascending: false)
          .range(page.offset, page.offset + page.limit - 1),
      countQuery,
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
  Future<Result<InquiryStats>> getStats() => _guard(() async {
    final rows = await _client
        .from('patient_queries')
        .select('status')
        .eq('doctor_id', _doctorId);
    return InquiryStats(
      total: rows.length,
      newCount: rows.where((row) => row['status'] == 'new').length,
      responded: rows.where((row) => row['status'] == 'responded').length,
    );
  });

  @override
  Future<Result<void>> setStatus(String id, InquiryStatus status) =>
      _guard(() async {
        await _client
            .from('patient_queries')
            .update({'status': _statusValue(status)})
            .eq('id', id)
            .eq('doctor_id', _doctorId);
      });

  @override
  Stream<void> watchChanges() {
    final controller = StreamController<void>();
    final channel = _client
        .channel('mobile-inquiries-$_doctorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'patient_queries',
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

  static PatientInquiry _fromJson(Map<String, dynamic> row) => PatientInquiry(
    id: row['id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    message: row['message'] as String,
    status: _statusFromValue(row['status'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  static InquiryStatus _statusFromValue(String value) => switch (value) {
    'new' => InquiryStatus.newMessage,
    'read' => InquiryStatus.read,
    'responded' => InquiryStatus.responded,
    _ => throw StateError('Unsupported inquiry status: $value'),
  };

  static String _statusValue(InquiryStatus status) => switch (status) {
    InquiryStatus.newMessage => 'new',
    InquiryStatus.read => 'read',
    InquiryStatus.responded => 'responded',
  };

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
          if (error is PostgrestException && error.code == '42501') {
            throw const PermissionFailure();
          }
          throw ServerFailure(cause: error, stackTrace: stackTrace);
        }
      });
}
