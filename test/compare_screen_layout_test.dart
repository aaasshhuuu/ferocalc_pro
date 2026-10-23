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

  group('CompareScreen Layout & Overflow Prevention Tests', () {
    testWidgets('1. Small screen height 500dp has zero overflow errors', (tester) async {
      tester.view.physicalSize = const Size(800, 500);
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
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('2. Very constrained screen height 400dp has zero overflow errors', (tester) async {
      tester.view.physicalSize = const Size(800, 400);
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
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('3. Simulating software keyboard inset (viewInsets.bottom: 280) has zero overflow errors', (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CompareScreen), findsOneWidget);

      // Focus and enter text while keyboard is present
      final searchField = find.widgetWithText(TextField, 'Search banks...');
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'sbi');
      await tester.pump();

      // Scroll to view the filtered result
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.text('State Bank of India'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('4. CompareScreen scrollability: scroll down and up without conflicts', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Scroll down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Scroll back up
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('5. Bank card tap navigates to Bank Details', (tester) async {
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

      final firstCard = find.byType(FdRateCard).first;
      expect(firstCard, findsOneWidget);
      await tester.tap(firstCard);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('FD Rates — Regular'), findsNothing);
      expect(find.text('Official bank rates are being verified and will be available in a future update.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('6. Empty state with search query renders cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 500);
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
      await tester.enterText(searchField, 'no_such_bank_at_all');
      await tester.pump();

      // Drag scroll view to see empty state on 500dp screen
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pump();

      expect(find.text('No banks found matching "no_such_bank_at_all"'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Clear search'));
      await tester.pump();

      expect(find.byType(FdRateCard), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('7. Compact filter layout renders in minimal vertical space with all filter chips', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(const ValueKey('compare_filters_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('compare_customer_chip')), findsOneWidget);
      expect(find.text('Customer: Regular'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Public'), findsOneWidget);
      expect(find.byKey(const ValueKey('compare_tenure_chip')), findsOneWidget);
      expect(find.text('Tenure: 1 Year'), findsOneWidget);
      expect(find.byKey(const ValueKey('compare_deposit_chip')), findsOneWidget);
      expect(find.text('Deposit: ₹1,00,000'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('8. Customer Type chip quick-toggles between Regular and Senior Citizen', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final customerChip = find.byKey(const ValueKey('compare_customer_chip'));
      expect(customerChip, findsOneWidget);
      expect(find.text('Customer: Regular'), findsOneWidget);

      await tester.tap(customerChip);
      await tester.pump();

      expect(find.text('Customer: Senior'), findsOneWidget);

      await tester.tap(customerChip);
      await tester.pump();

      expect(find.text('Customer: Regular'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('9. Filters button opens bottom sheet with all filter controls and Apply works', (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byKey(const ValueKey('compare_filters_button')));
      await tester.pumpAndSettle();

      expect(find.text('Filter FD Rates'), findsOneWidget);
      expect(find.text('Senior Citizen'), findsOneWidget);
      expect(find.textContaining('Deposit Amount'), findsOneWidget);
      expect(find.textContaining('Apply Filters'), findsOneWidget);

      await tester.tap(find.text('Senior Citizen'));
      await tester.pump();

      await tester.tap(find.textContaining('Apply Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Filter FD Rates'), findsNothing);
      expect(find.text('Customer: Senior'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('10. Android Back dismisses filter bottom sheet without popping CompareScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.byKey(const ValueKey('compare_filters_button')));
      await tester.pumpAndSettle();

      expect(find.text('Filter FD Rates'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Filter FD Rates'), findsNothing);
      expect(find.byType(CompareScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('11. Calendar tenure selection: switch domain and pick 6 Months preset', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Open filters bottom sheet
      await tester.tap(find.byKey(const ValueKey('compare_filters_button')));
      await tester.pumpAndSettle();

      // Switch to Calendar domain
      final calSegment = find.text('Calendar');
      expect(calSegment, findsOneWidget);
      await tester.tap(calSegment);
      await tester.pumpAndSettle();

      // Verify Calendar presets are visible
      expect(find.byKey(const ValueKey('calendar_preset_6 Months')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_preset_1 Year')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_preset_2 Years')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_preset_3 Years')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_preset_5 Years')), findsOneWidget);

      // Select 6 Months preset
      await tester.tap(find.byKey(const ValueKey('calendar_preset_6 Months')));
      await tester.pumpAndSettle();

      // Apply Filters
      await tester.tap(find.textContaining('Apply Filters'));
      await tester.pumpAndSettle();

      // Verify tenure chip label is updated to 'Tenure: 6 Months'
      expect(find.text('Tenure: 6 Months'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('12. Custom calendar components entry and validation error handling', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Open filters
      await tester.tap(find.byKey(const ValueKey('compare_filters_button')));
      await tester.pumpAndSettle();

      // Switch to Calendar domain
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Enter invalid months (> 11)
      final monthsField = find.byKey(const ValueKey('calendar_input_Months'));
      expect(monthsField, findsOneWidget);
      await tester.enterText(monthsField, '15');
      await tester.pumpAndSettle();

      // Validation error displayed
      expect(find.byKey(const ValueKey('calendar_validation_error_text')), findsOneWidget);
      expect(find.text('Months must be between 0 and 11.'), findsOneWidget);

      // Enter all zeros (0 Years, 0 Months, 0 Days)
      final yearsField = find.byKey(const ValueKey('calendar_input_Years'));
      final daysField = find.byKey(const ValueKey('calendar_input_Days'));
      await tester.enterText(yearsField, '0');
      await tester.enterText(monthsField, '0');
      await tester.enterText(daysField, '0');
      await tester.pumpAndSettle();

      expect(find.text('At least one tenure component must be greater than zero.'), findsOneWidget);

      // Enter valid custom components (2 Years 3 Months 10 Days)
      await tester.enterText(yearsField, '2');
      await tester.enterText(monthsField, '3');
      await tester.enterText(daysField, '10');
      await tester.pumpAndSettle();

      // Error message cleared
      expect(find.byKey(const ValueKey('calendar_validation_error_text')), findsNothing);

      // Apply Filters
      await tester.tap(find.textContaining('Apply Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Tenure: 2 Years 3 Months 10 Days'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('13. Verified rates tab with calendar tenure renders cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Switch to Verified Rates tab
      final verifiedTab = find.byKey(const ValueKey('compare_source_verified'));
      expect(verifiedTab, findsOneWidget);
      await tester.tap(verifiedTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Open filters and switch to Calendar domain with 1 Year preset
      await tester.tap(find.byKey(const ValueKey('compare_filters_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('calendar_preset_1 Year')));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Apply Filters'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify empty state renders gracefully when no verified rates exist in DB
      expect(find.text('0 verified rates found'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('14. Regression: Days mode behavior unchanged and preserves 1 Year default', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Tenure: 1 Year'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('compare_filters_button')));
      await tester.pumpAndSettle();

      expect(find.text('Days'), findsOneWidget);
      await tester.tap(find.text('2 Years'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Apply Filters'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Tenure: 2 Years'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('15. CompareScreen in Calendar mode isolates fallback day estimates and renders reference approx indicator', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Open filters and switch to Calendar domain
      await tester.tap(find.byKey(const ValueKey('compare_filters_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('calendar_preset_1 Year')));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Apply Filters'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // On Reference tab (default): Summary indicates '(approx. days)'
      expect(find.textContaining('reference rates (approx. days)'), findsOneWidget);

      // Switch to Verified Official tab
      final verifiedTab = find.byKey(const ValueKey('compare_source_verified'));
      await tester.tap(verifiedTab);
      await tester.pumpAndSettle();

      // Verified tab shows exact count and empty state safely
      expect(find.text('0 verified rates found'), findsOneWidget);
      expect(find.textContaining('No verified rates found for this criteria'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
