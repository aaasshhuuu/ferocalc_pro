import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
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

  group('Top FD Rates (Unverified) See All Navigation Tests', () {
    testWidgets(
      'Issue #4A: Home screen contains Top FD Rates section, See All navigates to CompareScreen, and Android Back returns to Home',
      (tester) async {
        // Set physical size to mobile dimensions to test standard mobile layout
        tester.view.physicalSize = const Size(1080, 2240);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Start at Home
        appRouter.go('/home');
        await tester.pumpWidget(_buildTestApp());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // 1. Verify Home screen contains "Official Bank FD Rates" section and launch-safe notice
        final sectionTitleFinder = find.text('Official Bank FD Rates');
        expect(sectionTitleFinder, findsOneWidget);
        expect(find.text('Top FD Rates (Unverified)'), findsNothing);
        expect(find.text('Official bank rates are being verified and will be available in a future update.'), findsOneWidget);

        // Locate the exact "See All" button within the Official Bank FD Rates section header
        final sectionHeaderFinder = find.ancestor(
          of: sectionTitleFinder,
          matching: find.byType(Row),
        );
        expect(sectionHeaderFinder, findsOneWidget);

        final seeAllFinder = find.descendant(
          of: sectionHeaderFinder,
          matching: find.text('See All'),
        );
        expect(seeAllFinder, findsOneWidget);

        // 2. Tap "See All" and verify navigation to CompareScreen (full FD rates list)
        await tester.tap(seeAllFinder);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Compare FD Rates'), findsOneWidget);

        // 3. Android Back from Compare destination returns to Home
        final handledBack = await tester.binding.handlePopRoute();
        expect(handledBack, isTrue);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Verified back on Home screen
        expect(find.text('Popular Calculators'), findsOneWidget);
        expect(find.text('Official Bank FD Rates'), findsOneWidget);
        expect(find.text('Official bank rates are being verified and will be available in a future update.'), findsOneWidget);

        // Clean up widget tree
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
