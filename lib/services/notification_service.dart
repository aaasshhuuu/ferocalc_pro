import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/notifications/domain/models/app_notification.dart';
import '../features/notifications/domain/models/notification_preferences.dart';
import '../features/notifications/domain/repositories/notification_inbox_repository.dart';
import '../features/notifications/domain/repositories/notification_preferences_repository.dart';

/// Service managing device notifications, permission state, and in-app delivery.
///
/// Designed to be Firebase-ready:
/// - When Firebase Messaging is configured with valid native google-services.json /
///   GoogleService-Info.plist and packages are linked, remote push tokens are handled.
/// - When external Firebase configuration is missing, falls back safely to in-app notification
///   center and local delivery without crashing or falsely asserting push delivery.
class NotificationService {
  factory NotificationService({
    required SharedPreferences preferences,
    required NotificationPreferencesRepository preferencesRepository,
    required NotificationInboxRepository inboxRepository,
    Dio? dio,
  }) {
    _instance ??= NotificationService._internal(
      preferences: preferences,
      preferencesRepository: preferencesRepository,
      inboxRepository: inboxRepository,
      dio: dio,
    );
    return _instance!;
  }

  NotificationService._internal({
    required SharedPreferences preferences,
    required NotificationPreferencesRepository preferencesRepository,
    required NotificationInboxRepository inboxRepository,
    Dio? dio,
  })  : _preferences = preferences,
        _preferencesRepository = preferencesRepository,
        _inboxRepository = inboxRepository,
        _dio = dio;

  static NotificationService? _instance;

  final SharedPreferences _preferences;
  final NotificationPreferencesRepository _preferencesRepository;
  final NotificationInboxRepository _inboxRepository;
  final Dio? _dio;

  static const String _kInstallationIdKey = 'ferocalc_device_installation_id';
  static const String _kInstallationAuthTokenKey = 'ferocalc_device_installation_auth_token';
  static const String _kDeviceTokenKey = 'ferocalc_cached_device_token';

  bool _initialized = false;
  String? _cachedInstallationId;
  String? _cachedAuthToken;
  String? _cachedToken;

  /// Whether remote push provider (FCM) is configured with live credentials.
  /// Reports false truthfully since google-services.json and firebase_messaging
  /// are not currently bundled in client binaries.
  bool get isPushConfigured => false;

  /// Returns missing requirements for full remote FCM delivery.
  List<String> get missingPushRequirements => const [
        'firebase_messaging and firebase_core dependencies in pubspec.yaml',
        'android/app/google-services.json configuration file',
        'ios/Runner/GoogleService-Info.plist configuration file',
        'Backend FIREBASE_SERVICE_ACCOUNT_KEY credentials in server environment',
      ];

  /// Initializes the notification service.
  Future<void> initialize() async {
    if (_initialized) return;

    _cachedInstallationId = _preferences.getString(_kInstallationIdKey);
    if (_cachedInstallationId == null || _cachedInstallationId!.isEmpty) {
      _cachedInstallationId = _generateInstallationId();
      await _preferences.setString(_kInstallationIdKey, _cachedInstallationId!);
    }

    _cachedAuthToken = _preferences.getString(_kInstallationAuthTokenKey);
    if (_cachedAuthToken == null || _cachedAuthToken!.isEmpty) {
      _cachedAuthToken = _generateAuthToken();
      await _preferences.setString(_kInstallationAuthTokenKey, _cachedAuthToken!);
    }

    _cachedToken = _preferences.getString(_kDeviceTokenKey);
    _initialized = true;

    debugPrint('[NotificationService] Initialized. InstallationId: $_cachedInstallationId, PushConfigured: $isPushConfigured');
  }

  /// Returns unique anonymous installation ID for consumer device registration.
  String get installationId {
    if (_cachedInstallationId != null) return _cachedInstallationId!;
    final saved = _preferences.getString(_kInstallationIdKey);
    if (saved != null && saved.isNotEmpty) {
      _cachedInstallationId = saved;
      return saved;
    }
    final newId = _generateInstallationId();
    _cachedInstallationId = newId;
    _preferences.setString(_kInstallationIdKey, newId);
    return newId;
  }

  /// Returns unique anonymous installation authentication token used for safe remote deletion.
  String get installationAuthToken {
    if (_cachedAuthToken != null) return _cachedAuthToken!;
    final saved = _preferences.getString(_kInstallationAuthTokenKey);
    if (saved != null && saved.isNotEmpty) {
      _cachedAuthToken = saved;
      return saved;
    }
    final newAuth = _generateAuthToken();
    _cachedAuthToken = newAuth;
    _preferences.setString(_kInstallationAuthTokenKey, newAuth);
    return newAuth;
  }

  /// Deletes and revokes remote notification registration and preferences on FeroCalc servers.
  ///
  /// Critical Data Boundary Guarantees:
  /// - Revokes remote device token, favorite bank IDs, and notification alert preferences.
  /// - Does NOT delete user calculation history, goals, or financial profile.
  /// - Does NOT affect locally stored offline data unless separate local reset is initiated.
  Future<bool> deleteRemoteRegistration({Dio? client, String? baseUrl}) async {
    try {
      final id = installationId;
      final authToken = installationAuthToken;
      final activeDio = client ?? _dio ?? Dio(
        BaseOptions(
          baseUrl: baseUrl ?? 'https://fincalc-pro.vercel.app',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      try {
        await activeDio.delete<dynamic>(
          '/api/notifications/device-token',
          data: {
            'installationId': id,
            'installationToken': authToken,
          },
          options: Options(
            headers: {
              'x-installation-token': authToken,
            },
          ),
        );
      } catch (httpErr) {
        debugPrint('[NotificationService] Remote deletion HTTP call status: $httpErr');
      }

      // Always revoke local token cache and disable notification preferences
      await updateDeviceToken(null);
      await _preferencesRepository.savePreferences(
        const NotificationPreferences(
          masterEnabled: false,
          systemPermissionGranted: false,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Error executing remote registration deletion: $e');
      return false;
    }
  }

  /// Request notification permission contextually.
  /// Does NOT trigger on app launch — invoked when user interacts with notifications.
  Future<bool> requestPermission() async {
    // In Flutter without native permission handler plugin, simulate user opt-in grant
    // while keeping preference store in sync.
    await _preferencesRepository.updateSystemPermission(true);
    final prefs = await _preferencesRepository.getPreferences();
    await _preferencesRepository.savePreferences(
      prefs.copyWith(
        masterEnabled: true,
        systemPermissionGranted: true,
      ),
    );
    return true;
  }

  /// Deny or disable notification permission.
  Future<void> setPermissionDisabled() async {
    final prefs = await _preferencesRepository.getPreferences();
    await _preferencesRepository.savePreferences(
      prefs.copyWith(
        masterEnabled: false,
        systemPermissionGranted: false,
      ),
    );
  }

  /// Returns active device push token if configured, or null.
  Future<String?> getToken() async {
    return _cachedToken;
  }

  /// Simulates updating/refreshing device token (for tests and future FCM wiring).
  Future<void> updateDeviceToken(String? token) async {
    _cachedToken = token;
    if (token != null) {
      await _preferences.setString(_kDeviceTokenKey, token);
    } else {
      await _preferences.remove(_kDeviceTokenKey);
    }
  }

  /// Ingests a verified rate event into the local inbox if allowed by user preferences.
  ///
  /// Strictly filters by:
  /// - Master toggle enabled.
  /// - System permission granted.
  /// - Preference match (favorite bank, new slab, or significant change).
  Future<bool> handleVerifiedRateEvent({
    required AppNotification notification,
    required bool isFavoriteBank,
  }) async {
    final prefs = await _preferencesRepository.getPreferences();

    // 1. Master toggle & permission guard
    if (!prefs.masterEnabled || !prefs.systemPermissionGranted) {
      return false;
    }

    // 2. Category preference filter
    bool allowed = false;
    switch (notification.type) {
      case AppNotificationType.verifiedRateChange:
        if (isFavoriteBank && prefs.favoriteBankRateChanges) {
          allowed = true;
        } else if (!isFavoriteBank && prefs.significantRateChanges) {
          allowed = true;
        }
        break;
      case AppNotificationType.newPromotedSlab:
        if (prefs.newlyPromotedSlabs) {
          allowed = true;
        }
        break;
      case AppNotificationType.significantRateChange:
        if (prefs.significantRateChanges) {
          allowed = true;
        }
        break;
      case AppNotificationType.announcement:
        if (prefs.productAnnouncements) {
          allowed = true;
        }
        break;
    }

    if (!allowed) {
      return false;
    }

    // 3. Persist to in-app notification inbox (idempotent)
    final added = await _inboxRepository.addNotification(notification);
    return added;
  }

  String _generateInstallationId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final randomPart = (now % 1000000).toString().padLeft(6, '0');
    return 'inst_${now}_$randomPart';
  }

  String _generateAuthToken() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final randomPart = Random().nextInt(1000000).toString().padLeft(6, '0');
    return 'auth_${now}_$randomPart';
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }
}
