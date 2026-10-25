import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/insights/presentation/screens/insights_screen.dart';
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

  group('InsightsScreen.getRouteForTitle unit tests', () {
    test('resolves Quick Calculator titles to correct routes', () {
      expect(InsightsScreen.getRouteForTitle('SIP Calculator'), equals('/calculator/sip'));
      expect(InsightsScreen.getRouteForTitle('EMI Calculator'), equals('/calculator/emi'));
      expect(InsightsScreen.getRouteForTitle('FD Calculator'), equals('/calculator/fd'));
      expect(InsightsScreen.getRouteForTitle('Tax Calculator'), equals('/calculator/income_tax'));
    });

    test('resolves Financial Management titles to correct routes', () {
      expect(InsightsScreen.getRouteForTitle('Rule of 72'), equals('/insights/financial-management/rule-of-72'));
      expect(InsightsScreen.getRouteForTitle('Emergency Fund'), equals('/insights/financial-management/emergency-fund'));
      expect(InsightsScreen.getRouteForTitle('Start SIP Early'), equals('/insights/financial-management/start-sip-early'));
      expect(InsightsScreen.getRouteForTitle('Tax Saving'), equals('/insights/financial-management/tax-saving'));
      expect(InsightsScreen.getRouteForTitle('PPF Returns'), equals('/insights/financial-management/ppf-returns'));
      expect(InsightsScreen.getRouteForTitle('NPS Benefits'), equals('/insights/financial-management/nps-benefits'));
      expect(InsightsScreen.getRouteForTitle('FD Taxation'), equals('/insights/financial-management/fd-taxation'));
      expect(InsightsScreen.getRouteForTitle('Sukanya Samriddhi'), equals('/insights/financial-management/sukanya-samriddhi'));
      expect(InsightsScreen.getRouteForTitle('Rule of 114'), equals('/insights/financial-management/rule-of-114'));
      expect(InsightsScreen.getRouteForTitle('70/20/10 Rule'), equals('/insights/financial-management/70-20-10'));
    });

    test('resolves Financial Literacy title to hub route and removed tracker items to null', () {
      expect(InsightsScreen.getRouteForTitle('Financial Literacy'), equals('/financial-literacy'));
      expect(InsightsScreen.getRouteForTitle('RBI Repo Rate'), isNull);
      expect(InsightsScreen.getRouteForTitle('SBI Base Rate'), isNull);
      expect(InsightsScreen.getRouteForTitle('PPF Rate'), isNull);
    });

    test('returns null for non-calculator or unknown items', () {
      expect(InsightsScreen.getRouteForTitle('Market Data Unavailable'), isNull);
      expect(InsightsScreen.getRouteForTitle('Random Title'), isNull);
    });
  });

  group('Insights Screen Navigation Widget Tests', () {
    testWidgets('Tapping Quick Calculator buttons navigates to calculator and back', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/insights');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 1. Verify on Insights screen
      expect(find.byType(InsightsScreen), findsOneWidget);
      expect(find.text('Quick Calculators'), findsOneWidget);

      // 2. Tap SIP Calculator
      final sipFinder = find.widgetWithText(InkWell, 'SIP Calculator');
      expect(sipFinder, findsOneWidget);
      await tester.ensureVisible(sipFinder);
      await tester.tap(sipFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify on SIP Calculator screen
      expect(find.text('SIP Calculator'), findsWidgets);

      // Back returns to Insights screen
      final handledBack1 = await tester.binding.handlePopRoute();
      expect(handledBack1, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);

      // 3. Tap EMI Calculator
      final emiFinder = find.widgetWithText(InkWell, 'EMI Calculator');
      expect(emiFinder, findsOneWidget);
      await tester.ensureVisible(emiFinder);
      await tester.tap(emiFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('EMI Calculator'), findsWidgets);

      // Back returns to Insights screen
      final handledBack2 = await tester.binding.handlePopRoute();
      expect(handledBack2, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);

      // Clean up
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Tapping Financial Management card navigates to detail screen and back', (tester) async {
      tester.view.physicalSize = const Size(1080, 2240);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/insights');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap 'Rule of 72' card
      final rule72Finder = find.text('Rule of 72');
      expect(rule72Finder, findsOneWidget);
      await tester.ensureVisible(rule72Finder);
      await tester.tap(rule72Finder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Navigated to Financial Management detail screen
      expect(find.text('Rule of 72'), findsWidgets);
      expect(find.text('What is it?'), findsOneWidget);
      expect(find.text('Why It Matters'), findsOneWidget);

      // Back returns to Insights
      final handledBack = await tester.binding.handlePopRoute();
      expect(handledBack, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);

      // Clean up
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Interest Rate Tracker is removed and Financial Literacy card navigates to Hub and back', (tester) async {
      tester.view.physicalSize = const Size(1080, 2240);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/insights');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify Interest Rate Tracker is completely removed
      expect(find.text('Interest Rate Tracker'), findsNothing);
      expect(find.text('RBI Repo Rate'), findsNothing);
      expect(find.text('SBI Base Rate'), findsNothing);

      // Verify Financial Literacy entry card is present
      final literacyCardFinder = find.byKey(const ValueKey('financial_literacy_entry_card'));
      expect(literacyCardFinder, findsOneWidget);
      await tester.ensureVisible(literacyCardFinder);
      await tester.tap(literacyCardFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Navigated to Financial Literacy Hub
      expect(find.text('Financial Literacy Hub'), findsWidgets);
      expect(find.byKey(const ValueKey('literacy_search_field')), findsOneWidget);

      // Back returns to Insights
      final handledBack = await tester.binding.handlePopRoute();
      expect(handledBack, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);

      // Clean up
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
