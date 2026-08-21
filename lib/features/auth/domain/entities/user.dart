import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String photoUrl;
  final String authProvider;
  final String role;
  final bool isPremium;

  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.authProvider,
    required this.role,
    required this.isPremium,
  });

  @override
  List<Object> get props => [id, email, displayName, photoUrl, authProvider, role, isPremium];
}
