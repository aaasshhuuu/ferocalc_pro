import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Represents an authenticated Supabase admin/reviewer user session.
class AdminUserSession extends Equatable {
  const AdminUserSession({
    required this.token,
    required this.userId,
    required this.email,
    required this.role,
    this.expiresAt,
  });

  /// Parse a Supabase JWT into an [AdminUserSession].
  /// Extracts `app_metadata.ferocalc_role` (must be ADMIN or REVIEWER).
  /// Returns null if token is malformed or lacks an authorized role.
  static AdminUserSession? fromJwt(String token) {
    try {
      final parts = token.trim().split('.');
      if (parts.length != 3) return null;

      final normalized = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalized));
      final dynamic decoded = json.decode(payloadString);

      if (decoded is! Map<String, dynamic>) return null;

      final userId = decoded['sub']?.toString() ?? decoded['user_id']?.toString() ?? '';
      final email = decoded['email']?.toString() ?? '';

      // Check app_metadata.ferocalc_role (server-controlled)
      final appMetadata = decoded['app_metadata'] as Map<String, dynamic>?;
      final role = appMetadata?['ferocalc_role']?.toString().toUpperCase();

      if (role != 'ADMIN' && role != 'REVIEWER') {
        // Not an authorized FeroCalc role
        return null;
      }

      DateTime? expiresAt;
      final exp = decoded['exp'];
      if (exp is num) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      }

      return AdminUserSession(
        token: token.trim(),
        userId: userId,
        email: email,
        role: role!,
        expiresAt: expiresAt,
      );
    } catch (_) {
      return null;
    }
  }

  final String token;
  final String userId;
  final String email;
  final String role; // 'ADMIN' or 'REVIEWER'
  final DateTime? expiresAt;

  bool get isAdmin => role == 'ADMIN';
  bool get isReviewer => role == 'REVIEWER';
  bool get isAuthorized => isAdmin || isReviewer;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  @override
  List<Object?> get props => [token, userId, email, role, expiresAt];
}
