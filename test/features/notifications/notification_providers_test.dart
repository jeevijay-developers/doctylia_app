import 'package:doctylia_app/core/errors/app_failure.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/notifications/data/repositories/mock_notification_repository.dart';
import 'package:doctylia_app/features/notifications/domain/entities/app_notification.dart';
import 'package:doctylia_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:doctylia_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns the mock feed but rejects every write, to exercise rollback.
final class _RejectingRepository implements NotificationRepository {
  final _inner = MockNotificationRepository();

  @override
  Future<Result<List<AppNotification>>> list({int limit = 100}) =>
      _inner.list(limit: limit);

  @override
  Future<Result<void>> markRead(String id) async =>
      const Failure(PermissionFailure());

  @override
  Future<Result<void>> markAllRead() async =>
      const Failure(PermissionFailure());
}

ProviderContainer _container(NotificationRepository repository) {
  final container = ProviderContainer(
    overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('maps a notifications row and derives its category', () {
    final item = AppNotificationMapper.fromJson({
      'id': 'a1',
      'source_type': 'ticket_reply',
      'title': 'Support replied',
      'message': 'Done',
      'ticket_id': 't1',
      'sender_id': null,
      'is_read': false,
      'created_at': '2026-10-05T08:30:00+00:00',
    });
    expect(item.category, NotificationCategory.support);
    expect(item.ticketId, 't1');
    expect(item.isRead, isFalse);
    expect(item.createdAt.toUtc(), DateTime.utc(2026, 10, 5, 8, 30));

    String category(String type) => AppNotificationMapper.fromJson({
      'id': 'x',
      'source_type': type,
      'title': '',
      'message': '',
      'is_read': true,
      'created_at': '2026-10-05T08:30:00Z',
    }).category.name;
    expect(category('trial_warning'), 'account');
    expect(category('plan_warning'), 'account');
    expect(category('direct_message'), 'support');
    expect(category('broadcast'), 'announcement');
    expect(category('something_new'), 'other');
  });

  test('marks one and then all notifications read', () async {
    final container = _container(MockNotificationRepository());
    final feed = await container.read(notificationsProvider.future);
    expect(feed.first.createdAt.isAfter(feed.last.createdAt), isTrue);
    final unreadBefore = container.read(unreadNotificationCountProvider);
    expect(unreadBefore, greaterThan(1));

    final firstUnread = feed.firstWhere((item) => !item.isRead);
    final controller = container.read(notificationsProvider.notifier);
    expect(await controller.markRead(firstUnread.id), isNull);
    expect(container.read(unreadNotificationCountProvider), unreadBefore - 1);

    expect(await controller.markAllRead(), isNull);
    expect(container.read(unreadNotificationCountProvider), 0);
  });

  test('rolls back optimistic updates when the server rejects them', () async {
    final container = _container(_RejectingRepository());
    final feed = await container.read(notificationsProvider.future);
    final unreadBefore = container.read(unreadNotificationCountProvider);
    final controller = container.read(notificationsProvider.notifier);

    final error = await controller.markRead(
      feed.firstWhere((item) => !item.isRead).id,
    );
    expect(error, isNotNull);
    expect(container.read(unreadNotificationCountProvider), unreadBefore);

    expect(await controller.markAllRead(), isNotNull);
    expect(container.read(unreadNotificationCountProvider), unreadBefore);
  });
}
