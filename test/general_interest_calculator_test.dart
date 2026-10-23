import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/simple_interest_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/compound_interest_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/calculators_hub_screen.dart';
import 'package:fincalc_pro/features/history/data/models/calculation_history_entry.dart';
import 'package:fincalc_pro/features/history/domain/repositories/calculation_history_repository.dart';
import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;

Widget _buildTestApp({required Widget child}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()),
      BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

Widget _buildRoutedApp() {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()),
      BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
    ],
    child: MaterialApp.router(
      routerConfig: appRouter,
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  // ═══════════════════════════════════════════════════════════════
  // 1. SIMPLE INTEREST MATHEMATICAL UNIT TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Simple Interest - Mathematical Unit Tests', () {
    test('Standard Simple Interest in Years: SI = P × R × T / 100', () {
      // P = 10,000, R = 5%, T = 3 years -> SI = 1,500, Amount = 11,500
      final si = FinancialMath.calculateSimpleInterest(
        principal: 10000,
        annualRate: 5.0,
        time: 3,
        timeUnit: TimeUnit.years,
      );
      final amount = FinancialMath.calculateSimpleInterestAmount(
        principal: 10000,
        annualRate: 5.0,
        time: 3,
        timeUnit: TimeUnit.years,
      );

      expect(si, equals(1500.0));
      expect(amount, equals(11500.0));
    });

    test('Simple Interest with Months time unit: T_years = Months / 12', () {
      // P = 50,000, R = 12%, T = 6 months -> SI = 50,000 × 12 × 0.5 / 100 = 3,000
      final si = FinancialMath.calculateSimpleInterest(
        principal: 50000,
        annualRate: 12.0,
        time: 6,
        timeUnit: TimeUnit.months,
      );
      final amount = FinancialMath.calculateSimpleInterestAmount(
        principal: 50000,
        annualRate: 12.0,
        time: 6,
        timeUnit: TimeUnit.months,
      );

      expect(si, closeTo(3000.0, 0.001));
      expect(amount, closeTo(53000.0, 0.001));
    });

    test('Simple Interest with Days time unit: T_years = Days / 365', () {
      // P = 73,000, R = 10%, T = 73 days -> 73/365 = 0.2 years -> SI = 73,000 × 10 × 0.2 / 100 = 1,460
      final si = FinancialMath.calculateSimpleInterest(
        principal: 73000,
        annualRate: 10.0,
        time: 73,
        timeUnit: TimeUnit.days,
      );
      final amount = FinancialMath.calculateSimpleInterestAmount(
        principal: 73000,
        annualRate: 10.0,
        time: 73,
        timeUnit: TimeUnit.days,
      );

      expect(si, closeTo(1460.0, 0.001));
      expect(amount, closeTo(74460.0, 0.001));
    });

    test('Simple Interest Summary returns reconciled map', () {
      final summary = FinancialMath.calculateSimpleInterestSummary(
        principal: 100000,
        annualRate: 8.5,
        time: 2.5,
        timeUnit: TimeUnit.years,
      );

      expect(summary['principal']!, equals(100000.0));
      expect(summary['interest']!, closeTo(21250.0, 0.01));
      expect(summary['totalAmount']!, closeTo(121250.0, 0.01));
      expect(summary['totalAmount']!, equals(summary['principal']! + summary['interest']!));
    });

    test('Edge case: Zero principal returns zero interest and zero amount', () {
      final si = FinancialMath.calculateSimpleInterest(
        principal: 0,
        annualRate: 8.0,
        time: 5,
      );
      final amount = FinancialMath.calculateSimpleInterestAmount(
        principal: 0,
        annualRate: 8.0,
        time: 5,
      );
      final summary = FinancialMath.calculateSimpleInterestSummary(
        principal: 0,
        annualRate: 8.0,
        time: 5,
      );

      expect(si, equals(0.0));
      expect(amount, equals(0.0));
      expect(summary['totalAmount']!, equals(0.0));
    });

    test('Edge case: Zero rate returns zero interest and principal amount', () {
      final si = FinancialMath.calculateSimpleInterest(
        principal: 50000,
        annualRate: 0,
        time: 5,
      );
      final amount = FinancialMath.calculateSimpleInterestAmount(
        principal: 50000,
        annualRate: 0,
        time: 5,
      );

      expect(si, equals(0.0));
      expect(amount, equals(50000.0));
    });

    test('Edge case: Zero time returns zero interest and principal amount', () {
      final si = FinancialMath.calculateSimpleInterest(
        principal: 50000,
        annualRate: 7.5,
        time: 0,
      );
      final amount = FinancialMath.calculateSimpleInterestAmount(
        principal: 50000,
        annualRate: 7.5,
        time: 0,
      );

      expect(si, equals(0.0));
      expect(amount, equals(50000.0));
    });

    test('Edge case: Negative inputs are safely sanitized without crash', () {
      final si = FinancialMath.calculateSimpleInterest(
        principal: -10000,
        annualRate: -5,
        time: -2,
      );
      final amount = FinancialMath.calculateSimpleInterestAmount(
        principal: -10000,
        annualRate: -5,
        time: -2,
      );

      expect(si, equals(0.0));
      expect(amount, equals(0.0));
      expect(si.isNaN, isFalse);
      expect(si.isInfinite, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 2. COMPOUND INTEREST MATHEMATICAL UNIT TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Compound Interest - Mathematical Unit Tests', () {
    test('Yearly Compounding (n = 1): A = P × (1 + R/100)^T', () {
      // P = 10,000, R = 10%, T = 2 years, n = 1
      // A = 10,000 × (1.10)^2 = 12,100, CI = 2,100
      final amount = FinancialMath.calculateCompoundInterestAmount(
        principal: 10000,
        annualRate: 10.0,
        time: 2,
        timeUnit: TimeUnit.years,
        compoundingFrequency: 1,
      );
      final ci = FinancialMath.calculateCompoundInterest(
        principal: 10000,
        annualRate: 10.0,
        time: 2,
        timeUnit: TimeUnit.years,
        compoundingFrequency: 1,
      );

      expect(amount, closeTo(12100.0, 0.01));
      expect(ci, closeTo(2100.0, 0.01));
    });

    test('Half-Yearly Compounding (n = 2): A = P × (1 + R/200)^(2T)', () {
      // P = 10,000, R = 10%, T = 1 year, n = 2
      // A = 10,000 × (1 + 0.05)^2 = 10,000 × 1.1025 = 11,025, CI = 1,025
      final amount = FinancialMath.calculateCompoundInterestAmount(
        principal: 10000,
        annualRate: 10.0,
        time: 1,
        timeUnit: TimeUnit.years,
        compoundingFrequency: 2,
      );
      final ci = FinancialMath.calculateCompoundInterest(
        principal: 10000,
        annualRate: 10.0,
        time: 1,
        timeUnit: TimeUnit.years,
        compoundingFrequency: 2,
      );

      expect(amount, closeTo(11025.0, 0.01));
      expect(ci, closeTo(1025.0, 0.01));
    });

    test('Quarterly Compounding (n = 4): A = P × (1 + R/400)^(4T)', () {
      // P = 10,000, R = 10%, T = 1 year, n = 4
      // A = 10,000 × (1 + 0.025)^4 = 11,038.1289... -> CI = 1,038.13
      final amount = FinancialMath.calculateCompoundInterestAmount(
        principal: 10000,
        annualRate: 10.0,
        time: 1,
        timeUnit: TimeUnit.years,
        compoundingFrequency: 4,
      );
      final ci = FinancialMath.calculateCompoundInterest(
        principal: 10000,
        annualRate: 10.0,
        time: 1,
        timeUnit: TimeUnit.years,
        compoundingFrequency: 4,
      );

      expect(amount, closeTo(11038.13, 0.01));
      expect(ci, closeTo(1038.13, 0.01));
    });

    test('Monthly Compounding (n = 12): A = P × (1 + R/1200)^(12T)', () {
      // P = 10,000, R = 12%, T = 1 year, n = 12
      // A = 10,000 × (1.01)^12 = 11,268.2503... -> CI = 1,268.25
      final amount = FinancialMath.calculateCompoundInterestAmount(
        principal: 10000,
        annualRate: 12.0,
        time: 1,
        timeUnit: TimeUnit.years,
        compoundingFrequency: 12,
      );
      final ci = FinancialMath.calculateCompoundInterest(
        principal: 10000,
        annualRate: 12.0,
        time: 1,
        timeUnit: TimeUnit.years,
        compoundingFrequency: 12,
      );

      expect(amount, closeTo(11268.25, 0.01));
      expect(ci, closeTo(1268.25, 0.01));
    });

    test('Compound Interest with Months time unit', () {
      // P = 20,000, R = 12%, T = 18 months, Monthly compounding
      // T_years = 1.5, n = 12 -> exponent = 18 -> 20,000 × (1.01)^18 = 23,922.95
      final summary = FinancialMath.calculateCompoundInterestSummary(
        principal: 20000,
        annualRate: 12.0,
        time: 18,
        timeUnit: TimeUnit.months,
        compoundingFrequency: 12,
      );

      expect(summary['principal']!, equals(20000.0));
      expect(summary['totalAmount']!, closeTo(23922.95, 0.01));
      expect(summary['interest']!, closeTo(3922.95, 0.01));
    });

    test('Compound Interest with Days time unit', () {
      // P = 50,000, R = 10%, T = 365 days, Quarterly compounding (n=4)
      // T_years = 1.0 -> 50,000 × (1 + 0.025)^4 = 55,190.64
      final summary = FinancialMath.calculateCompoundInterestSummary(
        principal: 50000,
        annualRate: 10.0,
        time: 365,
        timeUnit: TimeUnit.days,
        compoundingFrequency: 4,
      );

      expect(summary['totalAmount']!, closeTo(55190.64, 0.01));
      expect(summary['interest']!, closeTo(5190.64, 0.01));
    });

    test('Edge case: Zero principal returns 0 for all outputs', () {
      final summary = FinancialMath.calculateCompoundInterestSummary(
        principal: 0,
        annualRate: 8.0,
        time: 5,
      );

      expect(summary['principal']!, equals(0.0));
      expect(summary['interest']!, equals(0.0));
      expect(summary['totalAmount']!, equals(0.0));
    });

    test('Edge case: Zero rate returns principal as amount and 0 interest', () {
      final amount = FinancialMath.calculateCompoundInterestAmount(
        principal: 100000,
        annualRate: 0,
        time: 5,
        compoundingFrequency: 4,
      );
      final ci = FinancialMath.calculateCompoundInterest(
        principal: 100000,
        annualRate: 0,
        time: 5,
        compoundingFrequency: 4,
      );

      expect(amount, equals(100000.0));
      expect(ci, equals(0.0));
    });

    test('Edge case: Zero time returns principal as amount and 0 interest', () {
      final amount = FinancialMath.calculateCompoundInterestAmount(
        principal: 100000,
        annualRate: 7.5,
        time: 0,
        compoundingFrequency: 4,
      );
      final ci = FinancialMath.calculateCompoundInterest(
        principal: 100000,
        annualRate: 7.5,
        time: 0,
        compoundingFrequency: 4,
      );

      expect(amount, equals(100000.0));
      expect(ci, equals(0.0));
    });

    test('Edge case: Negative inputs and zero/negative frequency handle safely', () {
      final amount = FinancialMath.calculateCompoundInterestAmount(
        principal: -10000,
        annualRate: -5.0,
        time: -3,
        compoundingFrequency: 0,
      );
      final ci = FinancialMath.calculateCompoundInterest(
        principal: -10000,
        annualRate: -5.0,
        time: -3,
        compoundingFrequency: -1,
      );

      expect(amount, equals(0.0));
      expect(ci, equals(0.0));
      expect(amount.isNaN, isFalse);
      expect(amount.isInfinite, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 3. WIDGET & UI INTEGRATION TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Simple Interest Screen Widget Tests', () {
    testWidgets('Renders all inputs, unit switchers, formula, chart, and buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const SimpleInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Simple Interest'), findsWidgets);
      expect(find.text('Principal Amount'), findsWidgets);
      expect(find.text('Interest Rate (p.a.)'), findsOneWidget);
      expect(find.text('Time Unit'), findsOneWidget);
      expect(find.text('Years'), findsOneWidget);
      expect(find.text('Months'), findsOneWidget);
      expect(find.text('Days'), findsOneWidget);
      expect(find.byKey(const ValueKey('calculate_button')), findsOneWidget);
      expect(find.text('Total Amount'), findsWidgets);
      expect(find.text('Formula'), findsOneWidget);
      expect(find.text('Breakdown'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('Switching time unit changes time input label and recalculates', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const SimpleInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      // Switch to Months
      await tester.tap(find.text('Months'));
      await tester.pumpAndSettle();

      expect(find.text('Time Period (Months)'), findsOneWidget);

      // Switch to Days
      await tester.tap(find.text('Days'));
      await tester.pumpAndSettle();

      expect(find.text('Time Period (Days)'), findsOneWidget);
    });

    testWidgets('Tapping Calculate saves calculation to history', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = di.sl<CalculationHistoryRepository>();
      await repo.clearHistory();

      await tester.pumpWidget(_buildTestApp(child: const SimpleInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      final history = await repo.getHistory();
      expect(history.isNotEmpty, isTrue);
      expect(history.first.calculatorId, equals('simple_interest'));
      expect(history.first.category, equals('General Interest'));
      expect(history.first.primaryResultLabel, equals('Total Amount'));
    });

    testWidgets('No overflow on narrow screen (360dp width)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const SimpleInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Compound Interest Screen Widget Tests', () {
    testWidgets('Renders all inputs, frequency dropdown, formula, chart, and buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const CompoundInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Compound Interest'), findsWidgets);
      expect(find.text('Principal Amount'), findsWidgets);
      expect(find.text('Interest Rate (p.a.)'), findsOneWidget);
      expect(find.text('Time Unit'), findsOneWidget);
      expect(find.text('Compounding Frequency'), findsOneWidget);
      expect(find.byKey(const ValueKey('compounding_frequency_dropdown')), findsOneWidget);
      expect(find.byKey(const ValueKey('calculate_button')), findsOneWidget);
      expect(find.text('Total Amount'), findsWidgets);
      expect(find.text('Formula'), findsOneWidget);
      expect(find.text('Breakdown'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('Changing compounding frequency updates calculation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const CompoundInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      // Tap frequency dropdown
      await tester.tap(find.byKey(const ValueKey('compounding_frequency_dropdown')));
      await tester.pumpAndSettle();

      // Select Monthly
      await tester.tap(find.text('Monthly').last);
      await tester.pumpAndSettle();

      // Tap calculate
      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      final repo = di.sl<CalculationHistoryRepository>();
      final history = await repo.getHistory();
      expect(history.first.calculatorId, equals('compound_interest'));
      expect(history.first.inputs['Compounding Frequency'], equals('Monthly'));
    });

    testWidgets('No overflow on narrow screen (360dp width)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const CompoundInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // 4. ROUTING & HUB INTEGRATION TESTS
  // ═══════════════════════════════════════════════════════════════
  group('General Interest Navigation & Discovery Tests', () {
    testWidgets('CalculatorsHubScreen contains General Interest category with both calculators', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const CalculatorsHubScreen()));
      await tester.pumpAndSettle();

      expect(find.text('General Interest'), findsOneWidget);
      expect(find.text('Simple Interest'), findsOneWidget);
      expect(find.text('Compound Interest'), findsOneWidget);
    });

    testWidgets('GoRouter navigates to Simple Interest screen via /calculator/simple_interest', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/calculator/simple_interest');
      await tester.pumpWidget(_buildRoutedApp());
      await tester.pumpAndSettle();

      expect(find.byType(SimpleInterestCalculatorScreen), findsOneWidget);
    });

    testWidgets('GoRouter navigates to Compound Interest screen via /calculator/compound_interest', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/calculator/compound_interest');
      await tester.pumpWidget(_buildRoutedApp());
      await tester.pumpAndSettle();

      expect(find.byType(CompoundInterestCalculatorScreen), findsOneWidget);
    });

    test('CalculationHistoryEntry icon returns correct icons for simple and compound interest', () {
      final simpleEntry = CalculationHistoryEntry(
        id: 'si_1',
        calculatorId: 'simple_interest',
        calculatorName: 'Simple Interest',
        timestamp: DateTime.now(),
        inputs: {},
        results: {},
        primaryResultLabel: 'Total Amount',
        primaryResultValue: '₹11,500',
      );
      final compoundEntry = CalculationHistoryEntry(
        id: 'ci_1',
        calculatorId: 'compound_interest',
        calculatorName: 'Compound Interest',
        timestamp: DateTime.now(),
        inputs: {},
        results: {},
        primaryResultLabel: 'Total Amount',
        primaryResultValue: '₹12,100',
      );

      expect(simpleEntry.icon, equals(Icons.percent));
      expect(compoundEntry.icon, equals(Icons.trending_up));
    });
  });
}
