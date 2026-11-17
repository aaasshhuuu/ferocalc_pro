import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/repositories/notification_inbox_repository.dart';

class NotificationInboxRepositoryImpl implements NotificationInboxRepository {
  NotificationInboxRepositoryImpl({required SharedPreferences preferences})
      : _preferences = preferences;

  static const String _kStorageKey = 'ferocalc_notification_inbox_v1';
  final SharedPreferences _preferences;

  @override
  Future<List<AppNotification>> getNotifications() async {
    final rawJson = _preferences.getString(_kStorageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final list = <AppNotification>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              final n = AppNotification.fromJson(item);
              if (n.id.isNotEmpty) {
                list.add(n);
              }
            } catch (_) {
              // Gracefully ignore corrupt records
            }
          }
        }
        // Newest first
        list.sort((a, b) => b.verifiedTimestamp.compareTo(a.verifiedTimestamp));
        return list;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<int> getUnreadCount() async {
    final list = await getNotifications();
    return list.where((n) => !n.isRead).length;
  }

  @override
  Future<bool> addNotification(AppNotification notification) async {
    if (notification.id.isEmpty) return false;

    final current = await getNotifications();

    // Idempotency check: Do not re-add if same id or non-empty eventId exists
    final duplicate = current.any((existing) {
      if (existing.id == notification.id) return true;
      if (notification.eventId.isNotEmpty &&
          existing.eventId.isNotEmpty &&
          existing.eventId == notification.eventId) {
        return true;
      }
      return false;
    });

    if (duplicate) {
      return false; // Suppressed duplicate
    }

    final updated = List<AppNotification>.from(current)..insert(0, notification);
    await _save(updated);
    return true;
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    final current = await getNotifications();
    final index = current.indexWhere((n) => n.id == notificationId);
    if (index >= 0 && !current[index].isRead) {
      current[index] = current[index].copyWith(isRead: true);
      await _save(current);
      return true;
    }
    return false;
  }

  @override
  Future<void> markAllAsRead() async {
    final current = await getNotifications();
    bool changed = false;
    final updated = current.map((n) {
      if (!n.isRead) {
        changed = true;
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    if (changed) {
      await _save(updated);
    }
  }

  @override
  Future<bool> deleteNotification(String notificationId) async {
    final current = await getNotifications();
    final initialLength = current.length;
    current.removeWhere((n) => n.id == notificationId);

    if (current.length != initialLength) {
      await _save(current);
      return true;
    }
    return false;
  }

  @override
  Future<void> clearAllNotifications() async {
    await _preferences.remove(_kStorageKey);
  }

  Future<void> _save(List<AppNotification> list) async {
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await _preferences.setString(_kStorageKey, encoded);
  }
}
