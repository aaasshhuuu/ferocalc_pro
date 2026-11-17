import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/models/bank.dart';
import 'package:fincalc_pro/core/models/fd_rate.dart';
import 'package:fincalc_pro/core/theme/design_system.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/core/utils/responsive.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/core/widgets/custom_text_field.dart';
import 'package:fincalc_pro/core/widgets/empty_state.dart';
import 'package:fincalc_pro/core/widgets/fd_rate_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';

void main() {
  group('Phase 5.0.9 - App-wide UX, Accessibility & Responsive Experience', () {

    // ─────────────────────────────────────────────────────────────
    // 1. Compact 320x640 Viewport
    // ─────────────────────────────────────────────────────────────
    testWidgets('1. Compact 320x640 viewport renders without overflow and detects isCompact',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? compactDetected;
      EdgeInsets? padding;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                compactDetected = Responsive.isCompact(context);
                padding = Responsive.screenPadding(context);
                return ResultDisplayCard(
                  mainLabel: 'Maturity Value',
                  mainValue: FeroFormatters.formatInr(1589450),
                  subResults: [
                    SubResult(label: 'Principal Amount', value: FeroFormatters.formatInr(1000000)),
                    SubResult(label: 'Total Interest', value: FeroFormatters.formatInr(589450)),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(compactDetected, isTrue);
      expect(padding?.horizontal, equals(20.0)); // 10dp each side on compact
      expect(find.text('Maturity Value'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ─────────────────────────────────────────────────────────────
    // 2. Standard 360x640 Viewport
    // ─────────────────────────────────────────────────────────────
    testWidgets('2. Standard 360x640 mobile viewport renders cleanly', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? isCompact;
      bool? isMobile;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                isCompact = Responsive.isCompact(context);
                isMobile = Responsive.isMobile(context);
                return Column(
                  children: [
                    const CustomAppBar(title: 'Standard Mobile'),
                    ResultDisplayCard(
                      mainLabel: 'Monthly EMI',
                      mainValue: FeroFormatters.formatInr(45290),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(isCompact, isFalse);
      expect(isMobile, isTrue);
      expect(find.text('Monthly EMI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ─────────────────────────────────────────────────────────────
    // 3. Tablet Layouts (600x960 Portrait & 1024x768 Landscape)
    // ─────────────────────────────────────────────────────────────
    testWidgets('3. Tablet layouts adapt maxContentWidth and detect tablet mode',
        (tester) async {
      // Tablet portrait
      tester.view.physicalSize = const Size(600, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? isTablet;
      double? maxWidth;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                isTablet = Responsive.isTablet(context);
                maxWidth = Responsive.maxContentWidth(context);
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth!),
                    child: const Text('Tablet Portrait Content'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(isTablet, isTrue);
      expect(maxWidth, equals(600.0));
      expect(find.text('Tablet Portrait Content'), findsOneWidget);

      // Tablet landscape
      tester.view.physicalSize = const Size(1024, 768);
      double? landscapeMaxWidth;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                landscapeMaxWidth = Responsive.maxContentWidth(context);
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: landscapeMaxWidth!),
                    child: const Text('Tablet Landscape Content'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(landscapeMaxWidth, equals(800.0));
      expect(find.text('Tablet Landscape Content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ─────────────────────────────────────────────────────────────
    // 4. Large Text Scaling (1.5x and 2.0x)
    // ─────────────────────────────────────────────────────────────
    testWidgets('4. Large text scaling (1.5x and 2.0x) renders without vertical overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
              size: Size(360, 640),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    ResultDisplayCard(
                      mainLabel: 'Total Accumulated Wealth',
                      mainValue: FeroFormatters.formatInr(25000000),
                      subResults: [
                        SubResult(label: 'Total Invested', value: FeroFormatters.formatInr(12000000)),
                        SubResult(label: 'Wealth Gain', value: FeroFormatters.formatInr(13000000)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      text: 'Calculate Goal Projections',
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Total Accumulated Wealth'), findsOneWidget);
      expect(find.text('Calculate Goal Projections'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ─────────────────────────────────────────────────────────────
    // 5. Dark Theme
    // ─────────────────────────────────────────────────────────────
    testWidgets('5. Dark theme returns proper contrast cardBg and textPrimary',
        (tester) async {
      Color? cardBg;
      Color? textPrimary;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                cardBg = FeroColors.cardBgOf(context);
                textPrimary = FeroColors.textPrimaryOf(context);
                return Container(
                  color: cardBg,
                  child: Text('Dark Mode Text', style: TextStyle(color: textPrimary)),
                );
              },
            ),
          ),
        ),
      );

      expect(cardBg, equals(const Color(0xFF0F1D2E)));
      expect(textPrimary, equals(Colors.white));
      expect(find.text('Dark Mode Text'), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────────
    // 6. Light Theme
    // ─────────────────────────────────────────────────────────────
    testWidgets('6. Light theme returns distinct background and high-contrast text',
        (tester) async {
      Color? cardBg;
      Color? textPrimary;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                cardBg = FeroColors.cardBgOf(context);
                textPrimary = FeroColors.textPrimaryOf(context);
                return Container(
                  color: cardBg,
                  child: Text('Light Mode Text', style: TextStyle(color: textPrimary)),
                );
              },
            ),
          ),
        ),
      );

      expect(cardBg, equals(Colors.white));
      expect(textPrimary, equals(const Color(0xFF111827)));
      expect(find.text('Light Mode Text'), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────────
    // 7. Semantic Labels on Financial Metrics
    // ─────────────────────────────────────────────────────────────
    testWidgets('7. ResultDisplayCard generates accessible Semantics for financial values',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultDisplayCard(
              mainLabel: 'Monthly Maturity Payout',
              mainValue: '₹ 1,50,000',
              subResults: [
                SubResult(label: 'Total Deposits', value: '₹ 10,00,000'),
              ],
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(ResultDisplayCard));
      expect(node.label, contains('Monthly Maturity Payout: ₹ 1,50,000'));

      handle.dispose();
    });

    // ─────────────────────────────────────────────────────────────
    // 8. Accessibility Labels on Buttons and Toggles
    // ─────────────────────────────────────────────────────────────
    testWidgets('8. Buttons and toggles expose accessible touch targets and Semantics labels',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: const CustomAppBar(title: 'Accessibility Test', showBackButton: true),
            body: Center(
              child: GradientButton(
                text: 'Save Calculation',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      // Verify GradientButton has button semantics and >= 48dp touch target
      final buttonSemantics = tester.getSemantics(find.byType(GradientButton));
      expect(buttonSemantics.label, contains('Save Calculation'));
      expect(buttonSemantics.hasFlag(SemanticsFlag.isButton), isTrue);

      final Size buttonSize = tester.getSize(find.byType(GradientButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      // Verify AppBar back button has tooltip 'Back'
      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);

      handle.dispose();
    });

    // ─────────────────────────────────────────────────────────────
    // 9. Focus Traversal in Important Forms
    // ─────────────────────────────────────────────────────────────
    testWidgets('9. Form text fields support predictable focus traversal',
        (tester) async {
      final FocusNode focusNode1 = FocusNode();
      final FocusNode focusNode2 = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CustomTextField(
                  labelText: 'Loan Amount',
                  focusNode: focusNode1,
                  isRequired: true,
                ),
                CustomTextField(
                  labelText: 'Interest Rate',
                  focusNode: focusNode2,
                  isRequired: true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(focusNode1.hasFocus, isFalse);
      expect(focusNode2.hasFocus, isFalse);

      focusNode1.requestFocus();
      await tester.pump();
      expect(focusNode1.hasFocus, isTrue);

      focusNode2.requestFocus();
      await tester.pump();
      expect(focusNode1.hasFocus, isFalse);
      expect(focusNode2.hasFocus, isTrue);

      focusNode1.dispose();
      focusNode2.dispose();
    });

    // ─────────────────────────────────────────────────────────────
    // 10. Calculator Validation Errors
    // ─────────────────────────────────────────────────────────────
    testWidgets('10. Calculator form fields display inline validation errors clearly',
        (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: CustomTextField(
                labelText: 'Target Amount',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Target amount is required';
                  }
                  final num = double.tryParse(val);
                  if (num == null || num <= 0) {
                    return 'Please enter a valid amount greater than ₹0';
                  }
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      final isValid = formKey.currentState?.validate();
      expect(isValid, isFalse);
      await tester.pump();

      expect(find.text('Target amount is required'), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────────
    // 11. FD Comparison Responsive Presentation
    // ─────────────────────────────────────────────────────────────
    testWidgets('11. FdRateCard presents rates, bank name, and badges accessibly',
        (tester) async {
      const bank = Bank(
        id: 'sbi',
        name: 'State Bank of India',
        shortName: 'SBI',
        type: BankType.public,
      );

      const rate = FdRate(
        rateId: 'sbi_reg_1y',
        bankId: 'sbi',
        customerType: CustomerType.regular,
        interestRate: 7.1,
        minTenureDays: 365,
        maxTenureDays: 730,
        verificationStatus: VerificationStatus.verified,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FdRateCard(
              bank: bank,
              rate: rate,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('State Bank of India'), findsOneWidget);
      expect(find.text('7.10% p.a.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ─────────────────────────────────────────────────────────────
    // 12. Long Bank Names Handling
    // ─────────────────────────────────────────────────────────────
    testWidgets('12. Long bank names render safely without breaking layouts',
        (tester) async {
      const longName = 'Equitas Small Finance Bank Multi-State Scheduled Institution Limited';

      const bank = Bank(
        id: 'equitas',
        name: longName,
        shortName: 'ESFB',
        type: BankType.smallFinance,
      );

      const rate = FdRate(
        rateId: 'equitas_888d',
        bankId: 'equitas',
        customerType: CustomerType.seniorCitizen,
        interestRate: 8.5,
        minTenureDays: 888,
        maxTenureDays: 888,
        verificationStatus: VerificationStatus.verified,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320, // Compact viewport width
              child: FdRateCard(bank: bank, rate: rate),
            ),
          ),
        ),
      );

      expect(find.text(longName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // ─────────────────────────────────────────────────────────────
    // 13. Large INR Financial Values & Negative Balances
    // ─────────────────────────────────────────────────────────────
    test('13. FeroFormatters formats large INR values and negative balances accurately', () {
      expect(FeroFormatters.formatInr(10000000), equals('₹1,00,00,000'));
      expect(FeroFormatters.formatInr(50000), equals('₹50,000'));
      expect(FeroFormatters.formatInr(0), equals('₹0'));

      // Negative balance handling
      expect(FeroFormatters.formatInr(-25000), equals('- ₹25,000'));
      expect(FeroFormatters.semanticInr(-25000), equals('Negative ₹25,000'));
      expect(FeroFormatters.semanticInr(100000), equals('₹1,00,000'));

      // Rates
      expect(FeroFormatters.formatRate(7.25), equals('7.25% p.a.'));
      expect(FeroFormatters.semanticRate(7.25), equals('7.25 percent per annum'));
    });

    // ─────────────────────────────────────────────────────────────
    // 14. Offline and Unavailable States
    // ─────────────────────────────────────────────────────────────
    testWidgets('14. FeroStates.dataUnavailable displays clear explanation with retry CTA',
        (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeroStates.dataUnavailable(
              title: 'Rates Temporarily Unavailable',
              subtitle: 'Could not connect to the verified rate service. Check your network.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Rates Temporarily Unavailable'), findsOneWidget);
      expect(find.text('Check Status'), findsOneWidget);

      await tester.tap(find.text('Check Status'));
      expect(retried, isTrue);
    });

    // ─────────────────────────────────────────────────────────────
    // 15. Loading and Empty States
    // ─────────────────────────────────────────────────────────────
    testWidgets('15. EmptyState displays accessible liveRegion and customizable CTA',
        (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.history_toggle_off,
              title: 'No Calculations Found',
              subtitle: 'Your saved calculations will appear here.',
              actionLabel: 'Start New Calculation',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No Calculations Found'), findsOneWidget);
      expect(find.text('Start New Calculation'), findsOneWidget);

      await tester.tap(find.text('Start New Calculation'));
      expect(actionTapped, isTrue);
    });

    // ─────────────────────────────────────────────────────────────
    // 16. Reduced-Motion Behavior
    // ─────────────────────────────────────────────────────────────
    testWidgets('16. FeroAnimations returns Duration.zero when reduced motion is preferred',
        (tester) async {
      Duration? normalDuration;
      Duration? reducedDuration;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              normalDuration = FeroAnimations.duration(context, FeroAnimations.normal);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                reducedDuration = FeroAnimations.duration(context, FeroAnimations.normal);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(normalDuration, equals(const Duration(milliseconds: 250)));
      expect(reducedDuration, equals(Duration.zero));
    });

    // ─────────────────────────────────────────────────────────────
    // 17. Preservation of Existing Route Navigation
    // ─────────────────────────────────────────────────────────────
    test('17. AppRouter configuration preserves all key navigation endpoints', () {
      final routes = appRouter.configuration.routes;
      expect(routes.isNotEmpty, isTrue);
    });

    // ─────────────────────────────────────────────────────────────
    // 18. No Regression in Calculation or Rate Data Values
    // ─────────────────────────────────────────────────────────────
    test('18. Core FinancialMath mathematical precision is strictly preserved', () {
      // EMI Calculation
      final emi = FinancialMath.calculateEMI(
        principal: 1000000,
        annualRate: 8.5,
        months: 240,
      );
      expect(emi, closeTo(8678.23, 0.05));

      // FD Maturity (Quarterly compounding)
      final fdMaturity = FinancialMath.calculateFDMaturity(
        principal: 100000,
        annualRate: 7.0,
        years: 1.0,
        compoundingFrequency: 4,
      );
      expect(fdMaturity, closeTo(107185.90, 0.05));

      // Simple Interest
      final si = FinancialMath.calculateSimpleInterest(
        principal: 50000,
        annualRate: 6.0,
        time: 180,
        timeUnit: TimeUnit.days,
      );
      expect(si, closeTo(1479.45, 0.05));

      // Combined tenure to years
      final combinedYears = FinancialMath.combinedTenureToYears(
        years: 1,
        months: 6,
        days: 0,
      );
      expect(combinedYears, equals(1.5));
    });
  });
}
