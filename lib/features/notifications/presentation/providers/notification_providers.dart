import 'package:doctylia_app/app/providers/repository_overrides.dart';
import 'package:doctylia_app/features/notifications/data/repositories/mock_notification_repository.dart';
import 'package:doctylia_app/features/notifications/domain/entities/app_notification.dart';
import 'package:doctylia_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden with the Supabase repository at bootstrap for remote flavors.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (!ref.watch(appDataSourceProvider).isMock) {
    throw UnsupportedError('Notification repository must be overridden.');
  }
  return MockNotificationRepository();
});

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(
      NotificationsController.new,
    );

/// Unread count of the loaded feed (0 until it has loaded).
final unreadNotificationCountProvider = Provider<int>(
  (ref) =>
      ref
          .watch(notificationsProvider)
          .value
          ?.where((item) => !item.isRead)
          .length ??
      0,
);

class NotificationsController extends AsyncNotifier<List<AppNotification>> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  @override
  Future<List<AppNotification>> build() => _load();

  Future<List<AppNotification>> _load() async {
    final result = await _repo.list();
    return result.fold(
      onSuccess: (items) => items,
      onFailure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_load);

  /// Marks one notification read, optimistically; reverts on failure and
  /// returns the error message.
  Future<String?> markRead(String id) async {
    final current = state.value;
    if (current == null) return null;
    final target = current.where((item) => item.id == id).firstOrNull;
    if (target == null || target.isRead) return null;
    state = AsyncData([
      for (final item in current)
        item.id == id ? item.copyWith(isRead: true) : item,
    ]);
    final result = await _repo.markRead(id);
    return result.fold(
      onSuccess: (_) => null,
      onFailure: (failure) {
        state = AsyncData(current);
        return failure.userMessage;
      },
    );
  }

  /// Marks every notification read, optimistically; reverts on failure.
  Future<String?> markAllRead() async {
    final current = state.value;
    if (current == null || current.every((item) => item.isRead)) return null;
    state = AsyncData([
      for (final item in current) item.copyWith(isRead: true),
    ]);
    final result = await _repo.markAllRead();
    return result.fold(
      onSuccess: (_) => null,
      onFailure: (failure) {
        state = AsyncData(current);
        return failure.userMessage;
      },
    );
  }
}
