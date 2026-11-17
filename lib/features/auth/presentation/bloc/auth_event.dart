import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class LoginRequested extends AuthEvent {
  const LoginRequested(this.email, this.password);
  final String email;
  final String password;
  @override
  List<Object> get props => [email, password];
}

class ContinueAsGuest extends AuthEvent {}

class LogoutRequested extends AuthEvent {}
