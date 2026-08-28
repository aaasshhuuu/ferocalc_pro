import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required String id,
    required String email,
    required String displayName,
    required String photoUrl,
    required String authProvider,
    required String role,
    required bool isPremium,
  }) : super(
          id: id,
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
          authProvider: authProvider,
          role: role,
          isPremium: isPremium,
        );

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString() ?? '',
      authProvider: json['authProvider']?.toString() ?? 'email',
      role: json['role']?.toString() ?? 'user',
      isPremium: (json['isPremium'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'authProvider': authProvider,
      'role': role,
      'isPremium': isPremium,
    };
  }

  factory UserModel.guest() {
    return const UserModel(
      id: 'guest',
      email: '',
      displayName: 'Guest',
      photoUrl: '',
      authProvider: 'guest',
      role: 'user',
      isPremium: false,
    );
  }
}
