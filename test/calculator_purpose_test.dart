import 'package:fincalc_pro/core/data/calculator_purpose_data.dart';
import 'package:fincalc_pro/core/widgets/calculator_purpose_card.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/compound_interest_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/emi_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/fd_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/simple_interest_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/sip_calculator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<String> expectedCalculatorIds = [
    // General Interest (2)
    'simple_interest',
    'compound_interest',
    // Loans & Borrowing (7)
    'emi',
    'loan_amount',
    'loan_term',
    'interest_rate',
    'home_loan_eligibility',
    'personal_loan_eligibility',
    'credit_card_emi',
    // Deposits & Fixed Income (4)
    'fd',
    'rd',
    'savings',
    'ppf',
    // Investments & Wealth (8)
    'sip',
    'swp',
    'lumpsum',
    'cagr',
    'stock_return',
    'dividend_yield',
    'nps',
    'epf',
    // Tax & Regulatory (2)
    'gst',
    'income_tax',
    // Planning & Future Goals (5)
    'retirement',
    'goal',
    'education',
    'inflation',
    'sukanya',
  ];

  group('Calculator Purpose Registry Data Tests', () {
    test('Registry contains exactly 28 calculators', () {
      expect(calculatorPurposeRegistry.length, equals(28));
      expect(expectedCalculatorIds.length, equals(28));
    });

    test('All 28 expected calculator IDs exist in registry with valid content', () {
      for (final id in expectedCalculatorIds) {
        final info = calculatorPurposeRegistry[id];
        expect(info, isNotNull, reason: 'Missing purpose info for calculator id: $id');
        expect(info!.id, equals(id));
        expect(
          info.calculatorName.trim().isNotEmpty,
          isTrue,
          reason: 'Calculator name must not be empty for $id',
        );
        expect(
          info.purpose.trim().isNotEmpty,
          isTrue,
          reason: 'Purpose text must not be empty for $id',
        );
        expect(
          info.purpose.length,
          greaterThanOrEqualTo(20),
          reason: 'Purpose text should be descriptive for $id',
        );
        expect(
          info.useCases.length,
          greaterThanOrEqualTo(2),
          reason: 'Should have at least 2 common use cases for $id',
        );
        for (final useCase in info.useCases) {
          expect(
            useCase.trim().isNotEmpty,
            isTrue,
            reason: 'Use case bullet must not be empty for $id',
          );
        }
        expect(info.usefulFor, isNotNull);
        expect(info.usefulFor!.trim().isNotEmpty, isTrue);
      }
    });

    test('getCalculatorPurpose returns matching info or null for unknown id', () {
      final emiInfo = getCalculatorPurpose('emi');
      expect(emiInfo, isNotNull);
      expect(emiInfo!.calculatorName, equals('EMI Calculator'));

      final unknownInfo = getCalculatorPurpose('unknown_id_123');
      expect(unknownInfo, isNull);
    });
  });

  group('CalculatorPurposeCard Widget Tests', () {
    Widget buildTestableWidget(Widget child, {Size size = const Size(360, 640)}) {
      return MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.light,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SingleChildScrollView(child: child),
          ),
        ),
      );
    }

    testWidgets('Renders all purpose card sections for valid calculatorId', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const CalculatorPurposeCard(calculatorId: 'emi'),
        ),
      );

      // Verify heading
      expect(find.text('What is this calculator used for?'), findsOneWidget);

      // Verify purpose description
      final emiInfo = calculatorPurposeRegistry['emi']!;
      expect(find.text(emiInfo.purpose), findsOneWidget);

      // Verify common use cases heading and items
      expect(find.text('Common use cases:'), findsOneWidget);
      for (final useCase in emiInfo.useCases) {
        expect(find.text(useCase), findsOneWidget);
      }

      // Verify "Useful for:" label and text
      expect(find.text('Useful for: '), findsOneWidget);
      expect(find.text(emiInfo.usefulFor!), findsOneWidget);
    });

    testWidgets('Renders SizedBox.shrink for invalid calculatorId', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const CalculatorPurposeCard(calculatorId: 'non_existent_calc'),
        ),
      );

      expect(find.text('What is this calculator used for?'), findsNothing);
      expect(find.byType(CalculatorPurposeCard), findsOneWidget);
    });

    testWidgets('Renders properly without overflow on 360x640 narrow screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final id in expectedCalculatorIds) {
        await tester.pumpWidget(
          buildTestableWidget(
            CalculatorPurposeCard(calculatorId: id),
            size: const Size(360, 640),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'Render error on 360dp width for $id');
        expect(find.text('What is this calculator used for?'), findsOneWidget);
      }
    });

    testWidgets('Renders properly in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: CalculatorPurposeCard(calculatorId: 'simple_interest'),
            ),
          ),
        ),
      );

      expect(find.text('What is this calculator used for?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Integration: Calculator Screens Include CalculatorPurposeCard', () {
    testWidgets('SimpleInterestCalculatorScreen includes CalculatorPurposeCard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SimpleInterestCalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final purposeFinder = find.byType(CalculatorPurposeCard);
      expect(purposeFinder, findsOneWidget);
      final widget = tester.widget<CalculatorPurposeCard>(purposeFinder);
      expect(widget.calculatorId, equals('simple_interest'));
    });

    testWidgets('CompoundInterestCalculatorScreen includes CalculatorPurposeCard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CompoundInterestCalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final purposeFinder = find.byType(CalculatorPurposeCard);
      expect(purposeFinder, findsOneWidget);
      final widget = tester.widget<CalculatorPurposeCard>(purposeFinder);
      expect(widget.calculatorId, equals('compound_interest'));
    });

    testWidgets('EmiCalculatorScreen includes CalculatorPurposeCard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmiCalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final purposeFinder = find.byType(CalculatorPurposeCard);
      expect(purposeFinder, findsOneWidget);
      final widget = tester.widget<CalculatorPurposeCard>(purposeFinder);
      expect(widget.calculatorId, equals('emi'));
    });

    testWidgets('FdCalculatorScreen includes CalculatorPurposeCard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FdCalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final purposeFinder = find.byType(CalculatorPurposeCard);
      expect(purposeFinder, findsOneWidget);
      final widget = tester.widget<CalculatorPurposeCard>(purposeFinder);
      expect(widget.calculatorId, equals('fd'));
    });

    testWidgets('SipCalculatorScreen includes CalculatorPurposeCard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SipCalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final purposeFinder = find.byType(CalculatorPurposeCard);
      expect(purposeFinder, findsOneWidget);
      final widget = tester.widget<CalculatorPurposeCard>(purposeFinder);
      expect(widget.calculatorId, equals('sip'));
    });
  });
}
