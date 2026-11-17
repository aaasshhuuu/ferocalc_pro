import 'package:equatable/equatable.dart';
import '../../domain/entities/user.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthGuest extends AuthState {}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
  @override
  List<Object?> get props => [user];
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
