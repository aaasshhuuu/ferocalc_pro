import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/privacy_policy_screen.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/profile_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  group('Issue #11: Removal of Login / Sign-In Placeholder Feature', () {
    testWidgets('1. Profile screen opens directly with no auth barrier and displays clean header', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/profile');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('FeroCalc Profile'), findsOneWidget);

      // Verify no guest login or sign in CTA
      expect(find.text('Sign In / Create Account'), findsNothing);
      expect(find.text('Welcome, Guest'), findsNothing);
      expect(find.text('Sign in to sync your calculations'), findsNothing);
      expect(find.text('Sign In'), findsNothing);
      expect(find.text('Log In'), findsNothing);
      expect(find.text('Login'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('2. No login forms, Google sign-in buttons, or placeholder auth dialogs exist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/profile');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsNothing);
      expect(find.textContaining('Login feature will be available soon with Firebase'), findsNothing);
      expect(find.textContaining('Google Sign-in coming soon with Firebase'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('3. Core Profile features remain 100% accessible (Customer Type, Theme, Share App, Rate Us)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/profile');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Customer type selector is visible
      expect(find.text('CUSTOMER TYPE'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Senior Citizen'), findsOneWidget);

      // Preferences (Theme & Notifications)
      expect(find.text('APP SETTINGS'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);

      // Scroll to Share App & Rate Us
      final shareTile = find.byKey(const ValueKey('profile_share_app_tile'));
      await tester.scrollUntilVisible(shareTile, 300);
      expect(shareTile, findsOneWidget);
      expect(find.text('Share App'), findsOneWidget);
      expect(find.text('Rate Us'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('4. Privacy Policy opens from Profile, back button works, and contains no login references', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/profile');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final privacyTile = find.text('Privacy Policy');
      await tester.scrollUntilVisible(privacyTile, 300);
      expect(privacyTile, findsOneWidget);

      await tester.tap(privacyTile);
      await tester.pumpAndSettle();

      // Verify PrivacyPolicyScreen opened
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(find.text('Privacy Policy'), findsAtLeastNWidgets(1));

      // Verify no login references in Privacy Policy text
      expect(find.textContaining('If you use the login feature'), findsNothing);

      // Test Android Back navigation
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Back at Profile screen
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    test('5. AppRouter does not register any /login route', () {
      final routes = appRouter.configuration.routes;
      bool hasLoginRoute = false;
      for (final route in routes) {
        if (route is GoRoute && (route.path == '/login' || route.name == 'login')) {
          hasLoginRoute = true;
        }
      }
      expect(hasLoginRoute, isFalse);
    });
  });
}
