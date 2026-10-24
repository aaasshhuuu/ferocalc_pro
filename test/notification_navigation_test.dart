import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/widgets/empty_state.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp() {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()),
      BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
    ],
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  group('Notification Navigation & Screen Tests', () {
    testWidgets(
        'Notification button exists on HomeScreen and navigates to NotificationsScreen',
        (tester) async {
      appRouter.go('/home');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find Notification button in HomeScreen header
      final notificationButtonFinder =
          find.byKey(const ValueKey('home_notification_button'));
      expect(notificationButtonFinder, findsOneWidget);

      // Tap Notification button
      await tester.tap(notificationButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify NotificationsScreen is displayed
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Welcome to FeroCalc'), findsOneWidget);
      expect(find.text('Bank FD Rates Updated'), findsOneWidget);
      expect(find.text('Financial Literacy Hub'), findsOneWidget);
    });

    testWidgets('Clear all button empties list and renders EmptyState',
        (tester) async {
      appRouter.go('/notifications');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Welcome to FeroCalc'), findsOneWidget);

      // Tap Clear all button
      final clearButton = find.byKey(const ValueKey('clear_notifications_button'));
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // EmptyState should now be shown
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No Notifications'), findsOneWidget);
      expect(find.textContaining("You're all caught up!"), findsOneWidget);
    });

    testWidgets(
        'Back button navigation returns from NotificationsScreen to HomeScreen',
        (tester) async {
      appRouter.go('/home');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Popular Calculators'), findsOneWidget);

      // Push Notifications
      appRouter.push('/notifications');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NotificationsScreen), findsOneWidget);

      // Tap in-app Back button (IconButton on CustomAppBar)
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Should be back on HomeScreen
      expect(find.byType(NotificationsScreen), findsNothing);
      expect(find.text('Popular Calculators'), findsOneWidget);
    });

    testWidgets(
        'Android hardware back button pops NotificationsScreen to HomeScreen',
        (tester) async {
      appRouter.go('/home');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Push Notifications
      appRouter.push('/notifications');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NotificationsScreen), findsOneWidget);

      // Simulate Android Back
      final popped = await tester.binding.handlePopRoute();
      expect(popped, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Returned to HomeScreen
      expect(find.byType(NotificationsScreen), findsNothing);
      expect(find.text('Popular Calculators'), findsOneWidget);
    });
  });
}
