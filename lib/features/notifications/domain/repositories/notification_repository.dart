import 'package:doctylia_app/core/result/result.dart';
import 'package:doctylia_app/features/notifications/domain/entities/app_notification.dart';

abstract interface class NotificationRepository {
  /// Most recent notifications for the signed-in user, newest first.
  Future<Result<List<AppNotification>>> list({int limit = 100});
  Future<Result<void>> markRead(String id);
  Future<Result<void>> markAllRead();
}
