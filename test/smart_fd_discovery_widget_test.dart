import 'package:dio/dio.dart';
import 'package:fincalc_pro/core/models/discovery_models.dart';
import 'package:fincalc_pro/core/models/verified_fd_rate.dart';
import 'package:fincalc_pro/core/services/verified_rate_service.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/fd_calculator_screen.dart';
import 'package:fincalc_pro/features/discovery/presentation/screens/advanced_fd_comparison_screen.dart';
import 'package:fincalc_pro/features/discovery/presentation/screens/smart_fd_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF091422),
      cardColor: const Color(0xFF132235),
    ),
    home: child,
  );
}

Dio _createMockDioWithRates(List<Map<String, dynamic>> rateJsonList) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.contains('verified-rates/banks')) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'ok',
                'data': [
                  {
                    'id': 'b-sbi',
                    'name': 'State Bank of India',
                    'short_name': 'SBI',
                    'official_website': 'https://sbi.co.in',
                  },
                  {
                    'id': 'b-pnb',
                    'name': 'Punjab National Bank',
                    'short_name': 'PNB',
                    'official_website': 'https://pnb.bank.in',
                  },
                  {
                    'id': 'b-canara',
                    'name': 'Canara Bank',
                    'short_name': 'CANARA',
                    'official_website': 'https://canarabank.bank.in',
                  },
                ],
              },
            ),
          );
        } else if (options.path.contains('verified-rates')) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'ok',
                'data': rateJsonList,
                'meta': {'source': 'verified', 'count': rateJsonList.length},
              },
            ),
          );
        } else {
          handler.next(options);
        }
      },
    ),
  );
  return dio;
}

void main() {
  setUp(() {
    VerifiedRateService.setDioForTesting(null);
  });

  tearDown(() {
    VerifiedRateService.setDioForTesting(null);
  });

  final sampleRate1 = {
    'id': 'rate-sbi-1y',
    'bank_id': 'b-sbi',
    'bank_name': 'State Bank of India',
    'bank_short_name': 'SBI',
    'customer_type': 'REGULAR',
    'min_tenure_days': 365,
    'max_tenure_days': 729,
    'min_deposit': 1000,
    'max_deposit': 20000000,
    'interest_rate': 6.80,
    'is_callable': true,
    'compounding_frequency': 'QUARTERLY',
    'effective_from': '2026-01-01T00:00:00.000Z',
    'source_url': 'https://sbi.co.in/rates',
    'source_tenure_text': '1 Year to less than 2 Years',
  };

  final sampleRate2 = {
    'id': 'rate-pnb-1y',
    'bank_id': 'b-pnb',
    'bank_name': 'Punjab National Bank',
    'bank_short_name': 'PNB',
    'customer_type': 'REGULAR',
    'min_tenure_days': 365,
    'max_tenure_days': 729,
    'min_deposit': 1000,
    'max_deposit': 20000000,
    'interest_rate': 7.25,
    'is_callable': true,
    'compounding_frequency': 'QUARTERLY',
    'effective_from': '2026-01-01T00:00:00.000Z',
    'source_url': 'https://pnb.bank.in/rates',
    'source_tenure_text': '1 Year to less than 2 Years',
  };

  final sampleRate3 = {
    'id': 'rate-canara-1y',
    'bank_id': 'b-canara',
    'bank_name': 'Canara Bank',
    'bank_short_name': 'CANARA',
    'customer_type': 'REGULAR',
    'min_tenure_days': 365,
    'max_tenure_days': 729,
    'min_deposit': 1000,
    'max_deposit': 20000000,
    'interest_rate': 7.00,
    'is_callable': true,
    'compounding_frequency': 'QUARTERLY',
    'effective_from': '2026-01-01T00:00:00.000Z',
    'source_url': 'https://canarabank.bank.in/rates',
    'source_tenure_text': '1 Year',
  };

  group('SmartFdDiscoveryScreen Widget Tests', () {
    testWidgets('Renders criteria inputs, loads verified rates and displays matching cards', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockDio = _createMockDioWithRates([sampleRate1, sampleRate2]);
      VerifiedRateService.setDioForTesting(mockDio);

      await tester.pumpWidget(_wrap(const SmartFdDiscoveryScreen()));
      await tester.pumpAndSettle();

      // Verify Header and title
      expect(find.text('Best for Me FD Finder'), findsOneWidget);
      expect(find.text('Smart FD Discovery'), findsOneWidget);
      expect(find.text('100% VERIFIED'), findsOneWidget);

      // Verify inputs rendered
      expect(find.text('Deposit Amount'), findsOneWidget);
      expect(find.text('Investment Tenure'), findsOneWidget);
      expect(find.text('Customer Category'), findsOneWidget);

      // Verify matches displayed (PNB with 7.25% should be highest return)
      expect(find.text('Matching options for your criteria (2)'), findsOneWidget);
      expect(find.text('Punjab National Bank'), findsOneWidget);
      expect(find.text('State Bank of India'), findsOneWidget);
      expect(find.text('7.25%'), findsOneWidget);
      expect(find.text('6.80%'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Calculate Returns'), findsNWidgets(2));
      expect(find.text('Compare'), findsNWidgets(2));
    });

    testWidgets('Tapping Compare allows multi-selection and displays bottom comparison bar', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockDio = _createMockDioWithRates([sampleRate1, sampleRate2, sampleRate3]);
      VerifiedRateService.setDioForTesting(mockDio);

      await tester.pumpWidget(_wrap(const SmartFdDiscoveryScreen()));
      await tester.pumpAndSettle();

      // Bottom bar not present initially
      expect(find.text('Compare Side-by-Side'), findsNothing);

      // Tap compare on first card
      await tester.tap(find.text('Compare').first);
      await tester.pumpAndSettle();

      // Bottom bar appears indicating 1 of 4 selected
      expect(find.text('1 of 4 options selected'), findsOneWidget);
      expect(find.text('Select 1 more option to compare'), findsOneWidget);

      // Tap compare on second card
      await tester.tap(find.text('Compare').at(1));
      await tester.pumpAndSettle();

      // Bottom bar updates to 2 of 4 selected and enables button
      expect(find.text('2 of 4 options selected'), findsOneWidget);
      expect(find.text('Compare Side-by-Side'), findsOneWidget);
    });

    testWidgets('Renders honest empty state with Trust Center button when no rates match', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockDio = _createMockDioWithRates([]); // Empty rates
      VerifiedRateService.setDioForTesting(mockDio);

      await tester.pumpWidget(_wrap(const SmartFdDiscoveryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No verified fixed deposits match your exact criteria.'), findsOneWidget);
      expect(find.text('View Bank Coverage'), findsOneWidget);
      expect(find.text('Reset Criteria'), findsOneWidget);
    });
  });

  group('AdvancedFdComparisonScreen Widget Tests', () {
    testWidgets('Renders side-by-side comparison matrix with identical baseline', (tester) async {
      final match1 = FdDiscoveryMatch(
        rate: VerifiedFdRate.fromJson(sampleRate1),
        criteria: const FdDiscoveryCriteria(depositAmount: 100000, tenureValue: 1),
        estimatedMaturity: 106975.0,
        estimatedInterest: 6975.0,
        tenureInYears: 1.0,
      );

      final match2 = FdDiscoveryMatch(
        rate: VerifiedFdRate.fromJson(sampleRate2),
        criteria: const FdDiscoveryCriteria(depositAmount: 100000, tenureValue: 1),
        estimatedMaturity: 107450.0,
        estimatedInterest: 7450.0,
        tenureInYears: 1.0,
      );

      await tester.pumpWidget(
        _wrap(
          AdvancedFdComparisonScreen(
            selectedMatches: [match1, match2],
            criteria: const FdDiscoveryCriteria(depositAmount: 100000, tenureValue: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Side-by-Side Comparison'), findsOneWidget);
      expect(find.text('Identical Comparison Baseline'), findsOneWidget);
      expect(find.text('2 Options'), findsOneWidget);

      // Verify both bank columns
      expect(find.text('State Bank of India'), findsOneWidget);
      expect(find.text('Punjab National Bank'), findsOneWidget);

      // Verify highest return badge on PNB
      expect(find.text('HIGHEST RETURN'), findsOneWidget);

      // Verify calculation methodology disclosure
      expect(find.text('Financial Calculation Methodology & Disclosure'), findsOneWidget);
      expect(find.byIcon(Icons.calculate_outlined), findsNWidgets(2));
    });
  });

  group('FdCalculatorScreen Verified Rate Integration Widget Tests', () {
    testWidgets('Displays verified rate banner and initializes inputs from discovery parameters', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FdCalculatorScreen(
            initialPrincipal: 250000,
            initialInterestRate: 7.25,
            initialYears: 2,
            initialMonths: 0,
            initialDays: 0,
            initialIsSeniorCitizen: false,
            appliedBankName: 'Punjab National Bank',
            appliedSourceUrl: 'https://pnb.bank.in/rates',
            appliedCompoundingFrequency: 'Quarterly',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify banner present
      expect(find.text('Verified Rate Applied: Punjab National Bank'), findsOneWidget);
      expect(find.textContaining('Official bank rate of 7.25% p.a. pre-loaded from Punjab National Bank'), findsOneWidget);
      expect(find.text('Official Source: https://pnb.bank.in/rates'), findsOneWidget);
    });
  });
}
