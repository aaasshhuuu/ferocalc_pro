import '../entities/user.dart';

abstract class AuthRepository {
  Future<User> loginWithEmail(String email, String password);
  Future<User> loginWithGoogle();
  Future<User> loginWithPhone(String phoneNumber);
  Future<User> registerWithEmail(String email, String password, String name);
  Future<User> guestLogin();
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<bool> isLoggedIn();
}
