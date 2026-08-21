import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

/// Stub auth repository for local development.
/// Replace with Firebase implementation after setup.
class AuthRepositoryImpl implements AuthRepository {
  User? _currentUser;

  @override
  Future<User> loginWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: email.split('@').first,
      photoUrl: '',
      authProvider: 'email',
      role: 'user',
      isPremium: false,
    );
    return _currentUser!;
  }

  @override
  Future<User> loginWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = const UserModel(
      id: 'google_user_1',
      email: 'user@gmail.com',
      displayName: 'Google User',
      photoUrl: '',
      authProvider: 'google',
      role: 'user',
      isPremium: false,
    );
    return _currentUser!;
  }

  @override
  Future<User> loginWithPhone(String phoneNumber) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = UserModel(
      id: 'phone_user_1',
      email: '',
      displayName: 'Phone User',
      photoUrl: '',
      authProvider: 'phone',
      role: 'user',
      isPremium: false,
    );
    return _currentUser!;
  }

  @override
  Future<User> registerWithEmail(String email, String password, String name) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: name,
      photoUrl: '',
      authProvider: 'email',
      role: 'user',
      isPremium: false,
    );
    return _currentUser!;
  }

  @override
  Future<User> guestLogin() async {
    _currentUser = UserModel.guest();
    return _currentUser!;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  @override
  Future<User?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<bool> isLoggedIn() async {
    return _currentUser != null;
  }
}
