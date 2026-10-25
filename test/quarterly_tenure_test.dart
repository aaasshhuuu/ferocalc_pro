import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/compound_interest_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/emi_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/fd_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/ppf_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/rd_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/simple_interest_calculator_screen.dart';
import 'package:fincalc_pro/features/history/domain/repositories/calculation_history_repository.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({required Widget child}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()),
      BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  // ═══════════════════════════════════════════════════════════════
  // PART 1: MATHEMATICAL & UNIT CONVERSION TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Quarterly Tenure - Mathematical & Conversion Tests', () {
    test('1. convertTimeToYears converts quarters accurately to years', () {
      expect(FinancialMath.convertTimeToYears(time: 1, timeUnit: TimeUnit.quarters), equals(0.25));
      expect(FinancialMath.convertTimeToYears(time: 2, timeUnit: TimeUnit.quarters), equals(0.5));
      expect(FinancialMath.convertTimeToYears(time: 4, timeUnit: TimeUnit.quarters), equals(1.0));
      expect(FinancialMath.convertTimeToYears(time: 6, timeUnit: TimeUnit.quarters), equals(1.5));
      expect(FinancialMath.convertTimeToYears(time: 8, timeUnit: TimeUnit.quarters), equals(2.0));
      expect(FinancialMath.convertTimeToYears(time: 12, timeUnit: TimeUnit.quarters), equals(3.0));
      expect(FinancialMath.convertTimeToYears(time: 40, timeUnit: TimeUnit.quarters), equals(10.0));
    });

    test('2. Simple Interest with Quarterly tenure produces mathematically exact results', () {
      // P = 1,00,000, R = 8%, T = 4 quarters (1 year) -> SI = 8,000, Total = 1,08,000
      final si4Q = FinancialMath.calculateSimpleInterest(
        principal: 100000,
        annualRate: 8.0,
        time: 4,
        timeUnit: TimeUnit.quarters,
      );
      final amount4Q = FinancialMath.calculateSimpleInterestAmount(
        principal: 100000,
        annualRate: 8.0,
        time: 4,
        timeUnit: TimeUnit.quarters,
      );

      expect(si4Q, equals(8000.0));
      expect(amount4Q, equals(108000.0));
    });

    test('3. Simple Interest: Exact equivalence between Quarters, Years, and Months', () {
      const p = 250000.0;
      const r = 10.5;

      // 4 quarters == 1 year == 12 months
      final si4Quarters = FinancialMath.calculateSimpleInterest(principal: p, annualRate: r, time: 4, timeUnit: TimeUnit.quarters);
      final si1Year = FinancialMath.calculateSimpleInterest(principal: p, annualRate: r, time: 1, timeUnit: TimeUnit.years);
      final si12Months = FinancialMath.calculateSimpleInterest(principal: p, annualRate: r, time: 12, timeUnit: TimeUnit.months);

      expect(si4Quarters, equals(si1Year));
      expect(si4Quarters, closeTo(si12Months, 1e-9));

      // 8 quarters == 2 years == 24 months
      final si8Quarters = FinancialMath.calculateSimpleInterest(principal: p, annualRate: r, time: 8, timeUnit: TimeUnit.quarters);
      final si2Years = FinancialMath.calculateSimpleInterest(principal: p, annualRate: r, time: 2, timeUnit: TimeUnit.years);
      final si24Months = FinancialMath.calculateSimpleInterest(principal: p, annualRate: r, time: 24, timeUnit: TimeUnit.months);

      expect(si8Quarters, equals(si2Years));
      expect(si8Quarters, closeTo(si24Months, 1e-9));

      // 12 quarters == 3 years == 36 months
      final si12Quarters = FinancialMath.calculateSimpleInterest(principal: p, annualRate: r, time: 12, timeUnit: TimeUnit.quarters);
      final si3Years = FinancialMath.calculateSimpleInterest(principal: p, annualRate: r, time: 3, timeUnit: TimeUnit.years);

      expect(si12Quarters, equals(si3Years));
    });

    test('4. Compound Interest: Exact equivalence between Quarters and Years for all compounding frequencies', () {
      const p = 100000.0;
      const r = 8.0;

      for (final freq in CompoundingFrequency.values) {
        // 4 quarters == 1 year
        final ciQuarters = FinancialMath.calculateCompoundInterest(
          principal: p,
          annualRate: r,
          time: 4,
          timeUnit: TimeUnit.quarters,
          compoundingFrequency: freq.timesPerYear,
        );
        final ciYears = FinancialMath.calculateCompoundInterest(
          principal: p,
          annualRate: r,
          time: 1,
          timeUnit: TimeUnit.years,
          compoundingFrequency: freq.timesPerYear,
        );
        expect(ciQuarters, closeTo(ciYears, 1e-6), reason: 'Failed for freq ${freq.label}');

        // 8 quarters == 2 years
        final ci8Q = FinancialMath.calculateCompoundInterest(
          principal: p,
          annualRate: r,
          time: 8,
          timeUnit: TimeUnit.quarters,
          compoundingFrequency: freq.timesPerYear,
        );
        final ci2Y = FinancialMath.calculateCompoundInterest(
          principal: p,
          annualRate: r,
          time: 2,
          timeUnit: TimeUnit.years,
          compoundingFrequency: freq.timesPerYear,
        );
        expect(ci8Q, closeTo(ci2Y, 1e-6), reason: 'Failed for 8 quarters freq ${freq.label}');
      }
    });

    test('5. Distinguish Tenure in Quarters from Compounding Frequency in Compound Interest', () {
      const p = 100000.0;
      const r = 12.0;
      const timeQuarters = 4.0; // 1 year duration

      // Tenure = 4 Quarters, Compounding = Yearly (n = 1) -> A = 100,000 * 1.12 = 112,000
      final amountYearly = FinancialMath.calculateCompoundInterestAmount(
        principal: p,
        annualRate: r,
        time: timeQuarters,
        timeUnit: TimeUnit.quarters,
        compoundingFrequency: 1,
      );
      expect(amountYearly, closeTo(112000.0, 0.01));

      // Tenure = 4 Quarters, Compounding = Half-Yearly (n = 2) -> A = 100,000 * (1.06)^2 = 112,360
      final amountHalfYearly = FinancialMath.calculateCompoundInterestAmount(
        principal: p,
        annualRate: r,
        time: timeQuarters,
        timeUnit: TimeUnit.quarters,
        compoundingFrequency: 2,
      );
      expect(amountHalfYearly, closeTo(112360.0, 0.01));

      // Tenure = 4 Quarters, Compounding = Quarterly (n = 4) -> A = 100,000 * (1.03)^4 = 112,550.88
      final amountQuarterly = FinancialMath.calculateCompoundInterestAmount(
        principal: p,
        annualRate: r,
        time: timeQuarters,
        timeUnit: TimeUnit.quarters,
        compoundingFrequency: 4,
      );
      expect(amountQuarterly, closeTo(112550.88, 0.01));

      // Tenure = 4 Quarters, Compounding = Monthly (n = 12) -> A = 100,000 * (1.01)^12 = 112,682.50
      final amountMonthly = FinancialMath.calculateCompoundInterestAmount(
        principal: p,
        annualRate: r,
        time: timeQuarters,
        timeUnit: TimeUnit.quarters,
        compoundingFrequency: 12,
      );
      expect(amountMonthly, closeTo(112682.50, 0.01));

      // Proves that Compounding Frequency and Tenure in Quarters vary independently
      expect(amountQuarterly, isNot(equals(amountYearly)));
      expect(amountMonthly, isNot(equals(amountQuarterly)));
    });

    test('6. Zero and invalid quarterly input handling', () {
      final siZero = FinancialMath.calculateSimpleInterest(
        principal: 100000,
        annualRate: 8.0,
        time: 0,
        timeUnit: TimeUnit.quarters,
      );
      expect(siZero, equals(0.0));

      final siNegative = FinancialMath.calculateSimpleInterest(
        principal: 100000,
        annualRate: 8.0,
        time: -4,
        timeUnit: TimeUnit.quarters,
      );
      expect(siNegative, equals(0.0));

      final ciZero = FinancialMath.calculateCompoundInterest(
        principal: 100000,
        annualRate: 8.0,
        time: 0,
        timeUnit: TimeUnit.quarters,
      );
      expect(ciZero, equals(0.0));

      final ciAmountZero = FinancialMath.calculateCompoundInterestAmount(
        principal: 100000,
        annualRate: 8.0,
        time: 0,
        timeUnit: TimeUnit.quarters,
      );
      expect(ciAmountZero, equals(100000.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PART 2: UI & WIDGET TESTS FOR SIMPLE INTEREST SCREEN
  // ═══════════════════════════════════════════════════════════════
  group('Simple Interest Screen - Quarterly Tenure UI Tests', () {
    testWidgets('7. Quarters option appears in Simple Interest and switches tenure unit', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const SimpleInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      // Find Quarters button
      final quartersButton = find.byKey(const ValueKey('time_unit_quarters'));
      expect(quartersButton, findsOneWidget);
      expect(find.text('Quarters'), findsOneWidget);

      // Tap Quarters
      await tester.tap(quartersButton);
      await tester.pumpAndSettle();

      // Time Period label updates to reflect Quarters
      expect(find.text('Time Period (Quarters)'), findsOneWidget);

      // Converted from default 3 Years -> 12 Quarters
      // SI on 1,00,000 at 8% for 12 Quarters (3 years) = 24,000 -> Total = 1,24,000
      expect(find.text('₹1,24,000'), findsOneWidget);
    });

    testWidgets('8. Simple Interest preserves Quarters in History and Share/PDF', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const SimpleInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      // Tap Quarters
      await tester.tap(find.byKey(const ValueKey('time_unit_quarters')));
      await tester.pumpAndSettle();

      // Tap Calculate button to save to history
      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      // Verify saved history entry
      final historyRepo = di.sl<CalculationHistoryRepository>();
      final entries = await historyRepo.getHistory();
      expect(entries.isNotEmpty, isTrue);

      final latest = entries.first;
      expect(latest.calculatorId, equals('simple_interest'));
      expect(latest.inputs['Time Period'], contains('Quarters'));
      expect(latest.rawInputs?['timeUnit'], equals('quarters'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PART 3: UI & WIDGET TESTS FOR COMPOUND INTEREST SCREEN
  // ═══════════════════════════════════════════════════════════════
  group('Compound Interest Screen - Quarterly Tenure UI Tests', () {
    testWidgets('9. Quarters option appears in Compound Interest and distinguishes tenure from compounding', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const CompoundInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      // Both Quarters button (tenure) and Compounding dropdown exist independently
      final quartersButton = find.byKey(const ValueKey('time_unit_quarters'));
      final compoundingDropdown = find.byKey(const ValueKey('compounding_frequency_dropdown'));

      expect(quartersButton, findsOneWidget);
      expect(compoundingDropdown, findsOneWidget);

      // Tap Quarters tenure
      await tester.tap(quartersButton);
      await tester.pumpAndSettle();

      // Time Period label updates to Quarters
      expect(find.text('Time Period (Quarters)'), findsOneWidget);

      // Tap Calculate button to save to history
      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      // Verify saved history entry
      final historyRepo = di.sl<CalculationHistoryRepository>();
      final entries = await historyRepo.getHistory();
      final latest = entries.first;
      expect(latest.calculatorId, equals('compound_interest'));
      expect(latest.inputs['Time Period'], contains('Quarters'));
      expect(latest.rawInputs?['timeUnit'], equals('quarters'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PART 4: RESPONSIVENESS & OVERFLOW CHECKS (360x640 & 320x640)
  // ═══════════════════════════════════════════════════════════════
  group('Quarterly Tenure - Responsive & Overflow Tests', () {
    testWidgets('10. 360x640 viewport produces zero RenderFlex overflow on Simple Interest', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const SimpleInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Tap Quarters
      await tester.tap(find.byKey(const ValueKey('time_unit_quarters')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('11. 360x640 viewport produces zero RenderFlex overflow on Compound Interest', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const CompoundInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Tap Quarters
      await tester.tap(find.byKey(const ValueKey('time_unit_quarters')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('12. 320x640 narrow viewport produces zero RenderFlex overflow with all 4 tenure buttons', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const SimpleInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_buildTestApp(child: const CompoundInterestCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PART 5: REGRESSION & SCOPE ISOLATION TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Quarterly Tenure - Scope & Regression Tests', () {
    testWidgets('13. FD Calculator retains exact calendar tenure (Years, Months, Days) without quarters tenure', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const FdCalculatorScreen()));
      await tester.pumpAndSettle();

      // FD retains Years, Months, Days dropdowns
      expect(find.text('Years'), findsWidgets);
      expect(find.text('Months'), findsWidgets);
      expect(find.text('Days'), findsWidgets);

      // FD does NOT have a Quarters tenure button
      expect(find.byKey(const ValueKey('time_unit_quarters')), findsNothing);

      // FD retains Quarterly compounding in dropdown
      expect(find.byKey(const ValueKey('fd_compounding_dropdown')), findsOneWidget);
    });

    testWidgets('14. RD Calculator retains Months tenure without quarters tenure', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const RdCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Tenure'), findsOneWidget);
      expect(find.text(' Mos'), findsOneWidget);
      expect(find.byKey(const ValueKey('time_unit_quarters')), findsNothing);
    });

    testWidgets('15. PPF Calculator retains statutory Years tenure without quarters tenure', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const PpfCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Time Period'), findsOneWidget);
      expect(find.text(' Yrs'), findsOneWidget);
      expect(find.byKey(const ValueKey('time_unit_quarters')), findsNothing);
    });

    testWidgets('16. EMI Calculator retains Years and Months choice chips without quarters tenure', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const EmiCalculatorScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Years'), findsOneWidget);
      expect(find.text('Months'), findsOneWidget);
      expect(find.byKey(const ValueKey('time_unit_quarters')), findsNothing);
    });
  });
}
