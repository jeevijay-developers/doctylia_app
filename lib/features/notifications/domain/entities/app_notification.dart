/// Display grouping for `notifications.source_type`.
enum NotificationCategory { account, support, announcement, other }

/// A row of `public.notifications` addressed to the signed-in user.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.ticketId,
    this.senderId,
  });

  final String id;

  /// Raw `source_type`, e.g. `trial_warning`, `plan_warning`,
  /// `ticket_reply`, `direct_message`, `broadcast`.
  final String sourceType;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? ticketId;
  final String? senderId;

  NotificationCategory get category => switch (sourceType) {
    'trial_warning' || 'plan_warning' => NotificationCategory.account,
    'ticket_reply' || 'direct_message' => NotificationCategory.support,
    'broadcast' => NotificationCategory.announcement,
    _ => NotificationCategory.other,
  };

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    sourceType: sourceType,
    title: title,
    message: message,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    ticketId: ticketId,
    senderId: senderId,
  );
}

abstract final class AppNotificationMapper {
  static AppNotification fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    sourceType: (json['source_type'] as String?) ?? 'other',
    title: (json['title'] as String?) ?? '',
    message: (json['message'] as String?) ?? '',
    isRead: (json['is_read'] as bool?) ?? false,
    createdAt:
        DateTime.tryParse('${json['created_at']}')?.toLocal() ?? DateTime.now(),
    ticketId: json['ticket_id'] as String?,
    senderId: json['sender_id'] as String?,
  );
}
