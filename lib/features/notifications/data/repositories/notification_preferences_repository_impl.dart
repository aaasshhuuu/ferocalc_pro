import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/notification_preferences.dart';
import '../../domain/repositories/notification_preferences_repository.dart';

class NotificationPreferencesRepositoryImpl
    implements NotificationPreferencesRepository {
  NotificationPreferencesRepositoryImpl({
    required SharedPreferences preferences,
  }) : _preferences = preferences;

  static const String _kStorageKey = 'ferocalc_notification_preferences_v1';
  final SharedPreferences _preferences;

  @override
  Future<NotificationPreferences> getPreferences() async {
    final rawJson = _preferences.getString(_kStorageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return const NotificationPreferences();
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return NotificationPreferences.fromJson(decoded);
      }
      return const NotificationPreferences();
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    final updated = preferences.copyWith(lastUpdated: DateTime.now());
    final encoded = jsonEncode(updated.toJson());
    await _preferences.setString(_kStorageKey, encoded);
  }

  @override
  Future<void> updateSystemPermission(bool granted) async {
    final current = await getPreferences();
    final updated = current.copyWith(
      systemPermissionGranted: granted,
      lastUpdated: DateTime.now(),
    );
    await savePreferences(updated);
  }

  @override
  Future<void> resetPreferences() async {
    await _preferences.remove(_kStorageKey);
  }
}
