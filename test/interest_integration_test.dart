import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/emi_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/fd_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/interest_rate_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/loan_amount_calculator_screen.dart';
import 'package:fincalc_pro/features/history/domain/repositories/calculation_history_repository.dart';
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  setUp(() async {
    final historyRepo = di.sl<CalculationHistoryRepository>();
    await historyRepo.clearHistory();
  });

  // ═════════════════════════════════════════════════════════════════
  // 1. MATHEMATICAL FORMULA TESTS
  // ═════════════════════════════════════════════════════════════════
  group('1. Math Layer - Flat Rate (SI) and Reducing (CI) Formulas', () {
    test('calculateFlatRateEMI calculates correct Simple Interest EMI', () {
      // Principal = 1,20,000, Rate = 10% p.a., Tenure = 12 months (1 year)
      // Total Interest = 1,20,000 * 10% * 1 = 12,000
      // Total Payment = 1,32,000
      // Monthly EMI = 1,32,000 / 12 = 11,000
      final emi = FinancialMath.calculateFlatRateEMI(
        principal: 120000,
        annualRate: 10.0,
        months: 12,
      );
      expect(emi, closeTo(11000.0, 0.01));
    });

    test('calculateFlatRateEMI with zero rate returns principal / months', () {
      final emi = FinancialMath.calculateFlatRateEMI(
        principal: 120000,
        annualRate: 0.0,
        months: 12,
      );
      expect(emi, closeTo(10000.0, 0.01));
    });

    test('calculateFlatRateLoanAmount calculates correct principal from EMI', () {
      // EMI = 11,000, Rate = 10%, Tenure = 12 months
      // Expected principal = 1,20,000
      final principal = FinancialMath.calculateFlatRateLoanAmount(
        emi: 11000,
        annualRate: 10.0,
        months: 12,
      );
      expect(principal, closeTo(120000.0, 0.01));
    });

    test('calculateFlatInterestRate calculates correct Flat Rate from EMI', () {
      // Principal = 1,20,000, EMI = 11,000, Months = 12
      // Total Payment = 1,32,000, Total Interest = 12,000, Years = 1
      // Flat Rate = (12,000 * 100) / (1,20,000 * 1) = 10.0%
      final rate = FinancialMath.calculateFlatInterestRate(
        principal: 120000,
        emi: 11000,
        months: 12,
      );
      expect(rate, closeTo(10.0, 0.01));
    });

    test('Comparing Flat Rate vs Reducing Balance EMI illustrates interest difference', () {
      // Loan = 10,00,000, Rate = 10% p.a., 5 years (60 months)
      // Reducing Balance EMI:
      final reducingEmi = FinancialMath.calculateEMI(
        principal: 1000000,
        annualRate: 10.0,
        months: 60,
      );
      // Flat Rate EMI:
      final flatEmi = FinancialMath.calculateFlatRateEMI(
        principal: 1000000,
        annualRate: 10.0,
        months: 60,
      );

      // Reducing EMI: ~21,247.04
      // Flat EMI: (10,00,000 + 500,000) / 60 = 25,000.00
      expect(reducingEmi, closeTo(21247.04, 1.0));
      expect(flatEmi, closeTo(25000.0, 0.01));
      expect(flatEmi, greaterThan(reducingEmi));
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // 2. EMI CALCULATOR SCREEN INTEGRATION TESTS
  // ═════════════════════════════════════════════════════════════════
  group('2. EMI Calculator - Reducing (CI) vs Flat Rate (SI) Integration', () {
    testWidgets('EMI screen allows toggling between Reducing and Flat Rate', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const EmiCalculatorScreen()));
      await tester.pumpAndSettle();

      // Verify Method choice chips exist
      expect(find.byKey(const ValueKey('emi_method_reducing')), findsOneWidget);
      expect(find.byKey(const ValueKey('emi_method_flat')), findsOneWidget);

      // Default is Reducing Balance
      expect(find.text('Reducing Balance'), findsWidgets);

      // Tap Flat Rate
      await tester.tap(find.byKey(const ValueKey('emi_method_flat')));
      await tester.pumpAndSettle();

      // Verify result card reflects Flat Rate method
      expect(find.text('Flat Rate'), findsWidgets);

      // Tap Calculate button to trigger history save
      await tester.ensureVisible(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      final historyRepo = di.sl<CalculationHistoryRepository>();
      final history = await historyRepo.getHistory();
      expect(history.isNotEmpty, isTrue);
      expect(history.first.inputs['Interest Scheme'], contains('Flat Rate'));
      expect(history.first.results['Calculation Method'], contains('Flat Rate'));
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // 3. FD CALCULATOR SCREEN INTEGRATION TESTS
  // ═════════════════════════════════════════════════════════════════
  group('3. FD Calculator - Cumulative (CI) vs Non-Cumulative (SI) Integration', () {
    testWidgets('FD screen allows toggling between Cumulative and Non-Cumulative SI', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const FdCalculatorScreen()));
      await tester.pumpAndSettle();

      // Verify Deposit Type choice chips exist
      expect(find.byKey(const ValueKey('fd_type_cumulative')), findsOneWidget);
      expect(find.byKey(const ValueKey('fd_type_simple')), findsOneWidget);

      // In Cumulative mode, compounding frequency dropdown exists
      expect(find.text('Compounding'), findsOneWidget);

      // Tap Non-Cumulative (SI)
      await tester.tap(find.byKey(const ValueKey('fd_type_simple')));
      await tester.pumpAndSettle();

      // Simple interest info is shown
      expect(find.textContaining('Simple Interest'), findsWidgets);
      expect(find.text('Deposit Type'), findsWidgets);

      // Tap Calculate button to trigger history save
      await tester.ensureVisible(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      final historyRepo = di.sl<CalculationHistoryRepository>();
      final history = await historyRepo.getHistory();
      expect(history.isNotEmpty, isTrue);
      expect(history.first.inputs['Deposit Type'], contains('Non-Cumulative'));
      expect(history.first.results['Deposit Scheme'], contains('Non-Cumulative (Simple Interest)'));
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // 4. INTEREST RATE CALCULATOR SCREEN INTEGRATION TESTS
  // ═════════════════════════════════════════════════════════════════
  group('4. Interest Rate Calculator - Effective CI & Flat Rate SI Display', () {
    testWidgets('Interest Rate screen computes and displays both Effective and Flat rates', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const InterestRateCalculatorScreen()));
      await tester.pumpAndSettle();

      // Main label is Effective Interest Rate (Reducing)
      expect(find.text('Effective Interest Rate (Reducing)'), findsOneWidget);

      // Sub-results contains Flat Rate (Simple Interest)
      expect(find.text('Flat Rate (Simple Interest)'), findsOneWidget);

      // Tap Calculate button
      await tester.ensureVisible(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      final historyRepo = di.sl<CalculationHistoryRepository>();
      final history = await historyRepo.getHistory();
      expect(history.isNotEmpty, isTrue);
      expect(history.first.results['Effective Rate (Reducing)'], isNotNull);
      expect(history.first.results['Flat Rate (Simple Interest)'], isNotNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // 5. LOAN AMOUNT CALCULATOR SCREEN INTEGRATION TESTS
  // ═════════════════════════════════════════════════════════════════
  group('5. Loan Amount Calculator - Reducing (CI) vs Flat Rate (SI) Integration', () {
    testWidgets('Loan Amount screen allows toggling between Reducing and Flat Rate', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const LoanAmountCalculatorScreen()));
      await tester.pumpAndSettle();

      // Verify Method choice chips exist
      expect(find.byKey(const ValueKey('loan_amount_method_reducing')), findsOneWidget);
      expect(find.byKey(const ValueKey('loan_amount_method_flat')), findsOneWidget);

      // Default is Reducing Balance
      expect(find.text('Reducing Balance'), findsWidgets);

      // Tap Flat Rate
      await tester.tap(find.byKey(const ValueKey('loan_amount_method_flat')));
      await tester.pumpAndSettle();

      // Result card reflects Flat Rate
      expect(find.text('Flat Rate'), findsWidgets);

      // Tap Calculate button
      await tester.ensureVisible(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      final historyRepo = di.sl<CalculationHistoryRepository>();
      final history = await historyRepo.getHistory();
      expect(history.isNotEmpty, isTrue);
      expect(history.first.inputs['Method'], contains('Flat Rate'));
      expect(history.first.results['Method'], contains('Flat Rate'));
    });
  });

  // ═════════════════════════════════════════════════════════════════
  // 6. RESPONSIVE NARROW SCREEN LAYOUT TESTS (Vivo Y93 / 360x640)
  // ═════════════════════════════════════════════════════════════════
  group('6. Responsive Layout - 360x640 Logical Pixels', () {
    testWidgets('EmiCalculatorScreen renders on 360x640 without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const EmiCalculatorScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('FdCalculatorScreen renders on 360x640 without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const FdCalculatorScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('InterestRateCalculatorScreen renders on 360x640 without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const InterestRateCalculatorScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('LoanAmountCalculatorScreen renders on 360x640 without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const LoanAmountCalculatorScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
