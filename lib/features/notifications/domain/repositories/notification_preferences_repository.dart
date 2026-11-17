import '../models/notification_preferences.dart';

abstract class NotificationPreferencesRepository {
  /// Loads saved notification preferences.
  Future<NotificationPreferences> getPreferences();

  /// Saves updated notification preferences.
  Future<void> savePreferences(NotificationPreferences preferences);

  /// Updates system permission status.
  Future<void> updateSystemPermission(bool granted);

  /// Resets to default preferences.
  Future<void> resetPreferences();
}
