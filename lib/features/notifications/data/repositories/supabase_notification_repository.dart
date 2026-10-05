import 'dart:async';

import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/logging/app_logger.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/notifications/domain/entities/app_notification.dart';
import 'package:doctylia_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads `public.notifications`. RLS limits SELECT/UPDATE to rows where
/// `recipient_user_id = auth.uid()`, and only `is_read` is ever written.
final class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;
  static const _columns =
      'id, source_type, title, message, ticket_id, sender_id, is_read, '
      'created_at';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return id;
  }

  @override
  Future<Result<List<AppNotification>>> list({int limit = 100}) =>
      _guard(() async {
        final rows = await _client
            .from('notifications')
            .select(_columns)
            .eq('recipient_user_id', _userId)
            .order('created_at', ascending: false)
            .limit(limit);
        return rows.map(AppNotificationMapper.fromJson).toList(growable: false);
      });

  @override
  Future<Result<void>> markRead(String id) => _guard(() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('recipient_user_id', _userId);
  });

  @override
  Future<Result<void>> markAllRead() => _guard(() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_user_id', _userId)
        .eq('is_read', false);
  });

  Future<Result<T>> _guard<T>(Future<T> Function() operation) =>
      RepositoryGuard.run(() async {
        try {
          return await operation();
        } catch (error, stackTrace) {
          if (error is AppFailure) rethrow;
          AppLogger.error(
            'Notification repository operation failed',
            error: error,
            stackTrace: stackTrace,
          );
          throw _mapFailure(error, stackTrace);
        }
      });

  static AppFailure _mapFailure(Object error, StackTrace stackTrace) {
    final text = error.toString().toLowerCase();
    if (error is TimeoutException ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable')) {
      return NetworkFailure(cause: error, stackTrace: stackTrace);
    }
    if (error is PostgrestException && error.code == '42501') {
      return const PermissionFailure();
    }
    return ServerFailure(cause: error, stackTrace: stackTrace);
  }
}
