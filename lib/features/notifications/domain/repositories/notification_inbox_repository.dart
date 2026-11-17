import '../models/app_notification.dart';

abstract class NotificationInboxRepository {
  /// Fetches all in-app notifications, newest first.
  Future<List<AppNotification>> getNotifications();

  /// Returns total count of unread notifications.
  Future<int> getUnreadCount();

  /// Adds a notification. Idempotent: returns false if [notification.eventId] or [notification.id] exists.
  Future<bool> addNotification(AppNotification notification);

  /// Marks a specific notification as read.
  Future<bool> markAsRead(String notificationId);

  /// Marks all notifications as read.
  Future<void> markAllAsRead();

  /// Deletes a specific notification by ID.
  Future<bool> deleteNotification(String notificationId);

  /// Clears entire notification history.
  Future<void> clearAllNotifications();
}
