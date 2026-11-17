import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/widgets/empty_state.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/notifications/domain/models/app_notification.dart';
import 'package:fincalc_pro/features/notifications/domain/repositories/notification_inbox_repository.dart';
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
      final inboxRepo = di.sl<NotificationInboxRepository>();
      await inboxRepo.clearAllNotifications();
      await inboxRepo.addNotification(
        AppNotification(
          id: 'welcome_1',
          eventId: 'evt_welcome_1',
          bankId: 'ferocalc',
          bankName: 'FeroCalc',
          type: AppNotificationType.announcement,
          title: 'Welcome to FeroCalc',
          message: 'Explore interest rates, calculators, and financial insights.',
          verifiedTimestamp: DateTime.now(),
        ),
      );
      await inboxRepo.addNotification(
        AppNotification(
          id: 'rates_1',
          eventId: 'evt_rates_1',
          bankId: 'sbi',
          bankName: 'SBI',
          type: AppNotificationType.verifiedRateChange,
          title: 'Bank FD Rates Updated',
          message: 'SBI retail deposit slabs updated with official verified rates.',
          verifiedTimestamp: DateTime.now(),
        ),
      );

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
      expect(find.text('Notification Center'), findsOneWidget);
      expect(find.text('Welcome to FeroCalc'), findsOneWidget);
      expect(find.text('Bank FD Rates Updated'), findsOneWidget);
    });

    testWidgets('Clear all button empties list and renders EmptyState',
        (tester) async {
      final inboxRepo = di.sl<NotificationInboxRepository>();
      await inboxRepo.clearAllNotifications();
      await inboxRepo.addNotification(
        AppNotification(
          id: 'welcome_clear',
          eventId: 'evt_welcome_clear',
          bankId: 'ferocalc',
          type: AppNotificationType.announcement,
          bankName: 'FeroCalc',
          title: 'Welcome to FeroCalc',
          message: 'This test notification will be cleared.',
          verifiedTimestamp: DateTime.now(),
        ),
      );

      appRouter.go('/notifications');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Welcome to FeroCalc'), findsOneWidget);

      // Open more options menu
      final moreOptionsButton = find.byKey(const ValueKey('notification_more_options_button'));
      expect(moreOptionsButton, findsOneWidget);
      await tester.tap(moreOptionsButton);
      await tester.pumpAndSettle();

      // Tap Clear all notifications option
      final clearAllOption = find.text('Clear all notifications');
      expect(clearAllOption, findsOneWidget);
      await tester.tap(clearAllOption);
      await tester.pumpAndSettle();

      // Confirm deletion in dialog
      final confirmButton = find.widgetWithText(ElevatedButton, 'Clear All');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // EmptyState should now be shown
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No Notifications Yet'), findsOneWidget);
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
