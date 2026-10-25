import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/widgets/fd_rate_card.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/compare/presentation/screens/compare_screen.dart';
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

  group('Issue #8A — Bank Search in Compare / FD Rates Screen', () {
    testWidgets('1. Empty search returns all current banks', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CompareScreen), findsOneWidget);
      final searchField = find.widgetWithText(TextField, 'Search banks...');
      expect(searchField, findsOneWidget);

      // Verify banks are rendered initially without search query
      expect(find.byType(FdRateCard), findsWidgets);
      expect(find.text('AU SFB'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('2 & 4. Search for SBI (case-insensitive, whitespace trimmed)', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final searchField = find.widgetWithText(TextField, 'Search banks...');
      // Type "  sbi  " with whitespace and lowercase
      await tester.enterText(searchField, '  sbi  ');
      await tester.pump();

      // SBI should match
      expect(find.text('State Bank of India'), findsOneWidget);
      // Other banks should not be visible in search results
      expect(find.text('HDFC Bank'), findsNothing);
      expect(find.text('ICICI Bank'), findsNothing);

      // Test uppercase "SBI"
      await tester.enterText(searchField, 'SBI');
      await tester.pump();
      expect(find.text('State Bank of India'), findsOneWidget);
      expect(find.text('HDFC Bank'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('3 & 5. Search for HDFC (partial name and shortName matching)', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final searchField = find.widgetWithText(TextField, 'Search banks...');
      await tester.enterText(searchField, 'hdfc');
      await tester.pump();

      expect(find.text('HDFC Bank'), findsOneWidget);
      expect(find.text('State Bank of India'), findsNothing);
      expect(find.text('AU SFB'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('6. Search for AU / AU Small Finance Bank', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final searchField = find.widgetWithText(TextField, 'Search banks...');

      // Search "au"
      await tester.enterText(searchField, 'au');
      await tester.pump();
      expect(find.text('AU SFB'), findsOneWidget);
      expect(find.text('State Bank of India'), findsNothing);

      // Search "AU Small Finance Bank"
      await tester.enterText(searchField, 'AU Small Finance Bank');
      await tester.pump();
      expect(find.text('AU SFB'), findsOneWidget);
      expect(find.text('State Bank of India'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('7 & 8. No-match empty state and clearing search restores all banks', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final searchField = find.widgetWithText(TextField, 'Search banks...');
      // Type non-existent query
      await tester.enterText(searchField, 'nonexistentbankxyz');
      await tester.pump();

      // Empty state visible with clean message and clear button
      expect(find.text('No banks found matching "nonexistentbankxyz"'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
      final clearSearchBtn = find.text('Clear search');
      expect(clearSearchBtn, findsOneWidget);

      // Tap 'Clear search' button
      await tester.tap(clearSearchBtn);
      await tester.pump();

      // Restores all banks
      expect(find.byType(FdRateCard), findsWidgets);
      expect(find.text('AU SFB'), findsOneWidget);

      // Also test suffix icon clear
      await tester.enterText(searchField, 'sbi');
      await tester.pump();
      expect(find.text('AU SFB'), findsNothing);

      final suffixClearIcon = find.descendant(
        of: searchField,
        matching: find.byIcon(Icons.clear),
      );
      expect(suffixClearIcon, findsOneWidget);
      await tester.tap(suffixClearIcon);
      await tester.pump();

      // Restores all banks again
      expect(find.byType(FdRateCard), findsWidgets);
      expect(find.text('AU SFB'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('9. Search works together with existing filters (e.g. Bank Type)', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final searchField = find.widgetWithText(TextField, 'Search banks...');

      // Filter by 'Public' bank type
      final publicChip = find.widgetWithText(ChoiceChip, 'Public');
      expect(publicChip, findsOneWidget);
      await tester.tap(publicChip);
      await tester.pump();

      // Now search for "au" (which is Small Finance, not Public)
      await tester.enterText(searchField, 'au');
      await tester.pump();

      // Should show empty state because AU is not a Public bank
      expect(find.text('No banks found matching "au"'), findsOneWidget);
      expect(find.text('AU SFB'), findsNothing);

      // Now switch Bank Type to 'Small Finance'
      final sfbChip = find.widgetWithText(ChoiceChip, 'Small Finance');
      expect(sfbChip, findsOneWidget);
      await tester.tap(sfbChip);
      await tester.pump();

      // Now AU SFB should appear!
      expect(find.text('AU SFB'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('10. Fincare is NOT returned when searched as a standalone bank', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final searchField = find.widgetWithText(TextField, 'Search banks...');
      await tester.enterText(searchField, 'fincare');
      await tester.pump();

      // Must not return Fincare SFB as a current standalone bank
      expect(find.text('Fincare SFB'), findsNothing);
      expect(find.text('No banks found matching "fincare"'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
