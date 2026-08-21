import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user.dart';

class GuestAuthService {
  final SharedPreferences _prefs;

  GuestAuthService(this._prefs);

  static const String _isGuestKey = 'auth_is_guest';
  static const String _isLoggedInKey = 'auth_is_logged_in';
  static const String _userEmailKey = 'auth_user_email';

  bool get isGuest => _prefs.getBool(_isGuestKey) ?? false;
  bool get isLoggedIn => _prefs.getBool(_isLoggedInKey) ?? false;

  User? get currentUser {
    if (isGuest) {
      return const User(
        id: 'guest_id',
        email: 'guest@FeroCalc.app',
        displayName: 'Guest',
        photoUrl: '',
        authProvider: 'guest',
        role: 'guest',
        isPremium: false,
      );
    } else if (isLoggedIn) {
      final email = _prefs.getString(_userEmailKey) ?? 'user@FeroCalc.app';
      return User(
        id: 'user_id',
        email: email,
        displayName: 'FeroCalc User',
        photoUrl: '',
        authProvider: 'email',
        role: 'user',
        isPremium: true,
      );
    }
    return null;
  }

  Future<User> loginAsGuest() async {
    await _prefs.setBool(_isGuestKey, true);
    await _prefs.setBool(_isLoggedInKey, false);
    return currentUser!;
  }

  Future<User> loginWithEmail(String email, String password) async {
    // Stubbed for now
    await _prefs.setBool(_isGuestKey, false);
    await _prefs.setBool(_isLoggedInKey, true);
    await _prefs.setString(_userEmailKey, email);
    return currentUser!;
  }

  Future<void> logout() async {
    await _prefs.remove(_isGuestKey);
    await _prefs.remove(_isLoggedInKey);
    await _prefs.remove(_userEmailKey);
  }
}
