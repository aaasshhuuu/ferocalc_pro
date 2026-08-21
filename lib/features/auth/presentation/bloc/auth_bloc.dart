import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../data/services/guest_auth_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GuestAuthService authService;

  AuthBloc({required this.authService}) : super(AuthInitial()) {
    on<CheckAuthStatus>((event, emit) async {
      emit(AuthLoading());
      try {
        if (authService.isLoggedIn) {
          emit(AuthAuthenticated(authService.currentUser!));
        } else if (authService.isGuest) {
          emit(AuthGuest());
        } else {
          emit(AuthInitial());
        }
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authService.loginWithEmail(event.email, event.password);
        emit(AuthAuthenticated(user));
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<ContinueAsGuest>((event, emit) async {
      emit(AuthLoading());
      try {
        await authService.loginAsGuest();
        emit(AuthGuest());
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<LogoutRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await authService.logout();
        emit(AuthInitial());
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });
  }
}
