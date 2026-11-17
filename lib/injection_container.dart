import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/security/secure_storage.dart';
import 'core/services/financial_literacy_translation_service.dart';
import 'features/admin/data/services/admin_api_service.dart';
import 'features/admin/data/services/admin_auth_service.dart';
import 'features/auth/data/services/guest_auth_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/calculators/data/services/calculator_preferences_service.dart';
import 'features/favorites/data/repositories/favorite_banks_repository_impl.dart';
import 'features/favorites/domain/repositories/favorite_banks_repository.dart';
import 'features/favorites/presentation/bloc/favorite_banks_bloc.dart';
import 'features/financial_insights/data/repositories/financial_profile_repository_impl.dart';
import 'features/financial_insights/domain/repositories/financial_profile_repository.dart';
import 'features/financial_insights/presentation/bloc/financial_insights_bloc.dart';
import 'features/goals/data/repositories/goal_repository_impl.dart';
import 'features/goals/domain/repositories/goal_repository.dart';
import 'features/goals/presentation/bloc/goal_bloc.dart';
import 'features/history/data/repositories/calculation_history_repository_impl.dart';
import 'features/history/domain/repositories/calculation_history_repository.dart';
import 'features/history/presentation/bloc/calculation_history_bloc.dart';
import 'features/notifications/data/repositories/notification_inbox_repository_impl.dart';
import 'features/notifications/data/repositories/notification_preferences_repository_impl.dart';
import 'features/notifications/domain/repositories/notification_inbox_repository.dart';
import 'features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'features/theme/bloc/theme_bloc.dart';
import 'services/notification_service.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  // Wait for any async initializations here (e.g. Firebase, SharedPreferences)
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Security & Storage
  sl.registerLazySingleton(() => SecureStorage());

  // Admin Services
  final adminAuthService = AdminAuthService(secureStorage: sl());
  await adminAuthService.init();
  sl.registerLazySingleton(() => adminAuthService);
  sl.registerLazySingleton(() => AdminApiService(authService: sl()));

  // Services & Repositories
  sl.registerLazySingleton(() => GuestAuthService(sl()));
  sl.registerLazySingleton(() => CalculatorPreferencesService(preferences: sl()));
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

  // Features - Goals
  sl.registerLazySingleton<GoalRepository>(
    () => GoalRepositoryImpl(preferences: sl()),
  );
  sl.registerFactory(() => GoalBloc(repository: sl()));

  // Features - Favorites
  sl.registerLazySingleton<FavoriteBanksRepository>(
    () => FavoriteBanksRepositoryImpl(preferences: sl()),
  );
  sl.registerFactory(() => FavoriteBanksBloc(repository: sl()));

  // Features - Notifications
  sl.registerLazySingleton<NotificationPreferencesRepository>(
    () => NotificationPreferencesRepositoryImpl(preferences: sl()),
  );
  sl.registerLazySingleton<NotificationInboxRepository>(
    () => NotificationInboxRepositoryImpl(preferences: sl()),
  );
  sl.registerLazySingleton(
    () => NotificationService(
      preferences: sl(),
      preferencesRepository: sl(),
      inboxRepository: sl(),
    ),
  );
  await sl<NotificationService>().initialize();

  // Features - Financial Insights
  sl.registerLazySingleton<FinancialProfileRepository>(
    () => FinancialProfileRepositoryImpl(preferences: sl()),
  );
  sl.registerFactory(
    () => FinancialInsightsBloc(
      profileRepository: sl(),
      goalRepository: sl(),
      historyRepository: sl(),
      favoriteBanksRepository: sl(),
    ),
  );
}
