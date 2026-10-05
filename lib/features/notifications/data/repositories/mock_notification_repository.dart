import 'package:doctylia_app/core/errors/repository_guard.dart';
import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/notifications/domain/entities/app_notification.dart';
import 'package:doctylia_app/features/notifications/domain/repositories/notification_repository.dart';

/// In-memory notifications mirroring the real `source_type` values.
final class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository() : _items = _seed();
  final List<AppNotification> _items;

  @override
  Future<Result<List<AppNotification>>> list({int limit = 100}) =>
      RepositoryGuard.run(
        () => ([..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
            .take(limit)
            .toList(growable: false),
      );

  @override
  Future<Result<void>> markRead(String id) => RepositoryGuard.run(() {
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) _items[index] = _items[index].copyWith(isRead: true);
  });

  @override
  Future<Result<void>> markAllRead() => RepositoryGuard.run(() {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isRead: true);
    }
  });

  static List<AppNotification> _seed() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 'n1',
        sourceType: 'trial_warning',
        title: 'Your free trial ends in 3 days',
        message:
            'Upgrade to keep managing appointments, patients and your '
            'website without interruption.',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      AppNotification(
        id: 'n2',
        sourceType: 'ticket_reply',
        title: 'Support replied to your ticket',
        message:
            'We have updated your clinic timings as requested. Let us know '
            'if anything else needs changing.',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 3)),
        ticketId: 'ticket-1',
      ),
      AppNotification(
        id: 'n3',
        sourceType: 'direct_message',
        title: 'Message from the Doctylia team',
        message: 'Your public booking page is now indexed on search engines.',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      AppNotification(
        id: 'n4',
        sourceType: 'broadcast',
        title: 'New: online consultations',
        message:
            'Premium doctors can now host Zoom consultations directly from '
            'an appointment.',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      AppNotification(
        id: 'n5',
        sourceType: 'plan_warning',
        title: 'Monthly appointment limit almost reached',
        message: 'You have used 45 of 50 appointments on your current plan.',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 12)),
      ),
    ];
  }
}
