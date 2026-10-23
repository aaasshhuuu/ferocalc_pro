import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/theme/bloc/theme_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/data/services/guest_auth_service.dart';

import 'core/services/financial_literacy_translation_service.dart';
import 'features/history/data/repositories/calculation_history_repository_impl.dart';
import 'features/history/domain/repositories/calculation_history_repository.dart';
import 'features/history/presentation/bloc/calculation_history_bloc.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  // Wait for any async initializations here (e.g. Firebase, SharedPreferences)
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Services & Repositories
  sl.registerLazySingleton(() => GuestAuthService(sl()));
  sl.registerLazySingleton<CalculationHistoryRepository>(
    () => CalculationHistoryRepositoryImpl(preferences: sl()),
  );
  sl.registerLazySingleton(
    () => FinancialLiteracyTranslationService(preferences: sl()),
  );
  FinancialLiteracyTranslationService.init(sharedPreferences);

  // Features - Theme
  sl.registerFactory(() => ThemeBloc(preferences: sl()));

  // Features - Auth
  sl.registerFactory(() => AuthBloc(authService: sl()));

  // Features - History
  sl.registerFactory(() => CalculationHistoryBloc(repository: sl()));
}
