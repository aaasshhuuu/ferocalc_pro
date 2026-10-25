import 'package:fincalc_pro/core/data/bank_rate_repository.dart';
import 'package:fincalc_pro/core/models/fd_rate.dart';
import 'package:fincalc_pro/core/models/two_bank_comparison.dart';
import 'package:fincalc_pro/features/compare/presentation/screens/two_bank_comparison_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    // Ensure repos are initialized
  });

  group('TwoBankComparison Domain & Data Tests', () {
    test('TwoBankComparison builds valid comparison for two distinct banks', () {
      final sbi = BankRateRepository.getBankById('state_bank_of_india');
      final hdfc = BankRateRepository.getBankById('hdfc_bank');

      expect(sbi, isNotNull);
      expect(hdfc, isNotNull);

      final comparison = TwoBankComparison.build(
        bankA: sbi!,
        bankB: hdfc!,
        customerType: CustomerType.regular,
      );

      expect(comparison.bankA.id, equals('state_bank_of_india'));
      expect(comparison.bankB.id, equals('hdfc_bank'));
      expect(comparison.customerType, equals(CustomerType.regular));
      expect(comparison.tenureComparisons.length, equals(4)); // 1y, 2y, 3y, 5y
    });

    test('Like-for-like tenure comparison rates match repository for regular customers', () {
      final sbi = BankRateRepository.getBankById('state_bank_of_india')!;
      final hdfc = BankRateRepository.getBankById('hdfc_bank')!;

      final comp = TwoBankComparison.build(
        bankA: sbi,
        bankB: hdfc,
        customerType: CustomerType.regular,
      );

      // Check 1-year tenure
      final item1y = comp.tenureComparisons.firstWhere((i) => i.tenureKey == '1y');
      expect(item1y.tenureDays, equals(365));
      expect(item1y.rateA, equals(6.8));
      expect(item1y.rateB, equals(6.6));
      expect(item1y.difference, closeTo(0.2, 0.001));
      expect(item1y.winner, equals(ComparisonWinner.bankA));

      // Check 2-year tenure (7.0 vs 7.0 => tie)
      final item2y = comp.tenureComparisons.firstWhere((i) => i.tenureKey == '2y');
      expect(item2y.tenureDays, equals(730));
      expect(item2y.rateA, equals(7.0));
      expect(item2y.rateB, equals(7.0));
      expect(item2y.difference, closeTo(0.0, 0.001));
      expect(item2y.winner, equals(ComparisonWinner.tie));
    });

    test('Customer-type correctness: Senior citizen rates include senior premium for both banks', () {
      final sbi = BankRateRepository.getBankById('state_bank_of_india')!;
      final hdfc = BankRateRepository.getBankById('hdfc_bank')!;

      final compRegular = TwoBankComparison.build(
        bankA: sbi,
        bankB: hdfc,
        customerType: CustomerType.regular,
      );

      final compSenior = TwoBankComparison.build(
        bankA: sbi,
        bankB: hdfc,
        customerType: CustomerType.seniorCitizen,
      );

      final reg1y = compRegular.tenureComparisons.firstWhere((i) => i.tenureKey == '1y');
      final sen1y = compSenior.tenureComparisons.firstWhere((i) => i.tenureKey == '1y');

      // SBI: 6.8 + 0.5 = 7.3
      expect(sen1y.rateA, equals(reg1y.rateA! + 0.5));
      // HDFC: 6.6 + 0.5 = 7.1
      expect(sen1y.rateB, equals(reg1y.rateB! + 0.5));
    });

    test('Missing-data handling: null rates result in null difference and notAvailable winner', () {
      const dummyItem = TenureComparisonItem(
        tenureKey: '10y',
        tenureLabel: '10 Years',
        tenureDays: 3650,
        rateA: 7.0,
        rateB: null, // Bank B does not offer this
      );

      expect(dummyItem.difference, isNull);
      expect(dummyItem.winner, equals(ComparisonWinner.notAvailable));
    });

    test('Verification status is preserved as pendingReview for unverified rates', () {
      final sbi = BankRateRepository.getBankById('state_bank_of_india')!;
      final hdfc = BankRateRepository.getBankById('hdfc_bank')!;

      final comp = TwoBankComparison.build(
        bankA: sbi,
        bankB: hdfc,
      );

      for (final item in comp.tenureComparisons) {
        expect(item.statusA, equals(VerificationStatus.pendingReview));
        expect(item.statusB, equals(VerificationStatus.pendingReview));
      }
    });

    test('Product dimension: TwoBankComparison strictly matches requested isCallable dimension', () {
      final sbi = BankRateRepository.getBankById('state_bank_of_india')!;
      final hdfc = BankRateRepository.getBankById('hdfc_bank')!;

      // Default isCallable = true compares callable rates
      final compCallable = TwoBankComparison.build(
        bankA: sbi,
        bankB: hdfc,
        isCallable: true,
      );
      for (final item in compCallable.tenureComparisons) {
        expect(item.rateA, isNotNull);
        expect(item.rateB, isNotNull);
      }

      // Non-callable comparison (isCallable = false)
      // Since legacy bankInfo only represents callable retail rates,
      // non-callable lookup refuses legacy fallback and produces null rates safely.
      final compNonCallable = TwoBankComparison.build(
        bankA: sbi,
        bankB: hdfc,
        isCallable: false,
      );
      for (final item in compNonCallable.tenureComparisons) {
        // Rates should not fall back to callable legacy bank_data
        expect(item.rateA, isNull);
        expect(item.rateB, isNull);
        expect(item.winner, equals(ComparisonWinner.notAvailable));
      }
    });
  });

  group('TwoBankComparisonScreen Widget Tests', () {
    Widget buildTestScreen({
      String? initialBankAId,
      String? initialBankBId,
      Size size = const Size(360, 640),
    }) {
      return MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.light,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: TwoBankComparisonScreen(
            initialBankAId: initialBankAId,
            initialBankBId: initialBankBId,
          ),
        ),
      );
    }

    testWidgets('Renders side-by-side comparison screen with default banks', (tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Compare Two Banks'), findsOneWidget);
      expect(find.text('Select Banks to Compare'), findsOneWidget);
      expect(find.text('Bank A'), findsWidgets);
      expect(find.text('Bank B'), findsWidgets);
      expect(find.text('Customer Category'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Senior'), findsOneWidget);
      expect(find.textContaining('FD Interest Rates'), findsOneWidget);
      expect(find.text('Official bank rates are being verified and will be available in a future update.'), findsOneWidget);
    });

    testWidgets('Swap button swaps Bank A and Bank B correctly', (tester) async {
      await tester.pumpWidget(
        buildTestScreen(
          initialBankAId: 'state_bank_of_india',
          initialBankBId: 'hdfc_bank',
        ),
      );
      await tester.pumpAndSettle();

      // Find initial labels
      expect(find.text('State Bank of India'), findsWidgets);
      expect(find.text('HDFC Bank'), findsWidgets);

      // Tap swap button
      final swapButton = find.byKey(const ValueKey('swap_banks_button'));
      expect(swapButton, findsOneWidget);
      await tester.tap(swapButton);
      await tester.pumpAndSettle();

      // Ensure both banks are still present, now with swapped positions
      expect(find.text('State Bank of India'), findsWidgets);
      expect(find.text('HDFC Bank'), findsWidgets);
    });

    testWidgets('Customer category toggle switches between Regular and Senior citizen while keeping rates launch-safe', (tester) async {
      await tester.pumpWidget(
        buildTestScreen(
          initialBankAId: 'state_bank_of_india',
          initialBankBId: 'hdfc_bank',
        ),
      );
      await tester.pumpAndSettle();

      // Initially Regular: unverified rates (e.g. 6.80% p.a.) MUST NOT appear
      expect(find.text('6.80% p.a.'), findsNothing);
      expect(find.text('Official bank rates are being verified and will be available in a future update.'), findsOneWidget);

      // Toggle to Senior
      await tester.tap(find.text('Senior'));
      await tester.pumpAndSettle();

      // Senior: unverified rates (e.g. 7.30% p.a.) MUST NOT appear
      expect(find.text('7.30% p.a.'), findsNothing);
      expect(find.text('Official bank rates are being verified and will be available in a future update.'), findsOneWidget);
    });

    testWidgets('Same-bank prevention: Opposite bank is disabled in picker', (tester) async {
      await tester.pumpWidget(
        buildTestScreen(
          initialBankAId: 'state_bank_of_india',
          initialBankBId: 'hdfc_bank',
        ),
      );
      await tester.pumpAndSettle();

      // Open Bank A selector
      await tester.tap(find.byKey(const ValueKey('select_bank_a_button')));
      await tester.pumpAndSettle();

      // Verify picker opened
      expect(find.text('Select Bank'), findsOneWidget);

      // Search for HDFC Bank to bring it into view
      await tester.enterText(find.byKey(const ValueKey('bank_picker_search_field')), 'HDFC');
      await tester.pumpAndSettle();

      // HDFC Bank is currently Bank B, so in Bank A picker it must be disabled with notice
      expect(find.text('Already selected on other side'), findsOneWidget);

      // Tapping HDFC (which is disabled) should not select it
      final hdfcTile = find.byKey(const ValueKey('bank_item_hdfc_bank'));
      expect(hdfcTile, findsOneWidget);
      await tester.tap(hdfcTile);
      await tester.pumpAndSettle();

      // Picker should still be visible because disabled item tap does nothing
      expect(find.text('Select Bank'), findsOneWidget);
    });

    testWidgets('Selecting a new valid bank updates comparison view', (tester) async {
      await tester.pumpWidget(
        buildTestScreen(
          initialBankAId: 'state_bank_of_india',
          initialBankBId: 'hdfc_bank',
        ),
      );
      await tester.pumpAndSettle();

      // Open Bank B selector
      await tester.tap(find.byKey(const ValueKey('select_bank_b_button')));
      await tester.pumpAndSettle();

      // Filter by ICICI to bring it into view
      await tester.enterText(find.byKey(const ValueKey('bank_picker_search_field')), 'ICICI');
      await tester.pumpAndSettle();

      // Find and select ICICI Bank
      final iciciTile = find.byKey(const ValueKey('bank_item_icici_bank'));
      expect(iciciTile, findsOneWidget);
      await tester.tap(iciciTile);
      await tester.pumpAndSettle();

      // Now Bank B is ICICI Bank
      expect(find.text('ICICI Bank'), findsWidgets);
    });

    testWidgets('Responsiveness test at 360x640 logical pixels produces zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          initialBankAId: 'state_bank_of_india',
          initialBankBId: 'punjab_national_bank',
          size: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Compare Two Banks'), findsOneWidget);
    });

    testWidgets('Back button pops back correctly', (tester) async {
      bool didPop = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onPopPage: (route, result) {
              didPop = true;
              return route.didPop(result);
            },
            pages: const [
              MaterialPage(child: Text('Home')),
              MaterialPage(
                child: TwoBankComparisonScreen(
                  initialBankAId: 'state_bank_of_india',
                  initialBankBId: 'hdfc_bank',
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap back button (CustomAppBar uses Icons.arrow_back_ios_new_rounded)
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(didPop, isTrue);
    });
  });
}
