import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/theme/bloc/theme_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/data/services/guest_auth_service.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  // Wait for any async initializations here (e.g. Firebase, SharedPreferences)
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Services
  sl.registerLazySingleton(() => GuestAuthService(sl()));

  // Features - Theme
  sl.registerFactory(() => ThemeBloc());
  
  // Features - Auth
  sl.registerFactory(() => AuthBloc(authService: sl()));
}
