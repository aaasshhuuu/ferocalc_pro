import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/security/secure_storage.dart';
import '../models/admin_user_session.dart';

/// Service managing Supabase admin session authentication, persistence, and state.
class AdminAuthService extends ChangeNotifier {
  AdminAuthService({
    required this.secureStorage,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );

  final SecureStorage secureStorage;
  final Dio _dio;

  static const String tokenStorageKey = 'jwt_token';

  // Staging Supabase defaults (from staging environment configuration)
  static const String defaultStagingSupabaseUrl = 'https://cqrslxngpwbtkjejlwty.supabase.co';
  static const String defaultStagingAnonKey = 'sb_publishable_lLHzt-2hzBXJdI-UOYXRwQ_Tauy1KJM';

  AdminUserSession? _currentSession;
  bool _isInitialized = false;

  AdminUserSession? get currentSession => _currentSession;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _currentSession != null && !_currentSession!.isExpired;
  bool get isAdmin => isAuthenticated && _currentSession!.isAdmin;
  bool get isReviewer => isAuthenticated && _currentSession!.isReviewer;
  String? get token => _currentSession?.token;

  /// Initialize session from secure storage.
  Future<void> init() async {
    try {
      final savedToken = await secureStorage.read(key: tokenStorageKey);
      if (savedToken != null && savedToken.trim().isNotEmpty) {
        final session = AdminUserSession.fromJwt(savedToken);
        if (session != null && !session.isExpired) {
          _currentSession = session;
        } else {
          await secureStorage.delete(key: tokenStorageKey);
          _currentSession = null;
        }
      }
    } catch (e) {
      debugPrint('[AdminAuthService] Error initializing session: $e');
      _currentSession = null;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Sign in with Supabase email & password against Supabase Auth REST API.
  Future<AdminUserSession> loginWithEmailPassword({
    required String email,
    required String password,
    String? supabaseUrl,
    String? anonKey,
  }) async {
    final cleanUrl = (supabaseUrl != null && supabaseUrl.trim().isNotEmpty)
        ? supabaseUrl.trim()
        : defaultStagingSupabaseUrl;
    final cleanAnonKey = (anonKey != null && anonKey.trim().isNotEmpty)
        ? anonKey.trim()
        : defaultStagingAnonKey;

    final tokenEndpoint = '${cleanUrl.replaceAll(RegExp(r'/+$'), '')}/auth/v1/token?grant_type=password';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        tokenEndpoint,
        data: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
        options: Options(
          headers: {
            'apikey': cleanAnonKey,
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data;
      if (data == null || data['access_token'] == null) {
        throw Exception('Invalid response from Supabase Auth: missing access_token');
      }

      final accessToken = data['access_token'].toString();
      return await loginWithToken(accessToken);
    } on DioException catch (e) {
      final msg = e.response?.data?['error_description'] ??
          e.response?.data?['msg'] ??
          e.response?.data?['message'] ??
          e.message ??
          'Authentication failed';
      throw Exception(msg);
    }
  }

  /// Sign in using an existing Supabase JWT.
  /// Parses the server-controlled `app_metadata.ferocalc_role`.
  Future<AdminUserSession> loginWithToken(String rawToken) async {
    final session = AdminUserSession.fromJwt(rawToken);
    if (session == null) {
      throw Exception(
        'Invalid token: The supplied JWT does not contain an authorized FeroCalc role '
        '(app_metadata.ferocalc_role must be ADMIN or REVIEWER).',
      );
    }

    if (session.isExpired) {
      throw Exception('The provided session token has already expired.');
    }

    _currentSession = session;
    await secureStorage.write(key: tokenStorageKey, value: session.token);
    notifyListeners();
    return session;
  }

  /// Explicitly set session for unit testing.
  @visibleForTesting
  void setSessionForTesting(AdminUserSession? session) {
    _currentSession = session;
    _isInitialized = true;
    notifyListeners();
  }

  /// Sign out and clear stored session.
  Future<void> logout() async {
    _currentSession = null;
    notifyListeners();
    try {
      await secureStorage.delete(key: tokenStorageKey);
    } catch (_) {}
  }
}
