import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:fincalc_pro/core/data/bank_rate_repository.dart';
import 'package:fincalc_pro/core/models/bank.dart';
import 'package:fincalc_pro/core/models/fd_rate.dart';
import 'package:fincalc_pro/core/models/verified_fd_rate.dart';
import 'package:fincalc_pro/core/widgets/fd_rate_card.dart';
import 'package:fincalc_pro/core/widgets/verified_rate_badge.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/compare/presentation/screens/compare_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
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

  group('VerifiedFdRate Model Extensions & Converter Tests', () {
    test('toFdRate converts VerifiedFdRate to FdRate preserving verified provenance', () {
      final verifiedRate = VerifiedFdRate(
        id: 'sbi-verified-01',
        bankId: 'bank-sbi',
        bankName: 'State Bank of India',
        bankShortName: 'SBI',
        bankSourceDomain: 'sbi.co.in',
        customerType: VerifiedCustomerType.regular,
        minTenureDays: 365,
        maxTenureDays: 730,
        minDeposit: 1000,
        maxDeposit: 10000000,
        interestRate: 6.80,
        isCallable: true,
        compoundingFrequency: CompoundingFrequency.quarterly,
        effectiveFrom: DateTime(2026, 9, 6),
        sourceUrl: 'https://sbi.co.in/web/interest-rates/deposit-rates',
        verifiedAt: DateTime(2026, 9, 6, 12, 0),
      );

      final fdRate = verifiedRate.toFdRate();
      expect(fdRate.rateId, 'sbi-verified-01');
      expect(fdRate.bankId, 'bank-sbi');
      expect(fdRate.customerType, CustomerType.regular);
      expect(fdRate.minTenureDays, 365);
      expect(fdRate.maxTenureDays, 730);
      expect(fdRate.interestRate, 6.80);
      expect(fdRate.verificationStatus, VerificationStatus.verified);
      expect(fdRate.verifiedAt, DateTime(2026, 9, 6, 12, 0));
      expect(fdRate.sourceUrl, 'https://sbi.co.in/web/interest-rates/deposit-rates');
      expect(fdRate.sourceName, 'Official sbi.co.in');
      expect(fdRate.prematureWithdrawalAllowed, isTrue);

      final bank = verifiedRate.toBank();
      expect(bank.id, 'bank-sbi');
      expect(bank.name, 'State Bank of India');
      expect(bank.shortName, 'SBI');
      expect(bank.status, BankStatus.active);
      expect(bank.officialWebsite, 'https://sbi.co.in/web/interest-rates/deposit-rates');
    });

    test('toFdRate correctly maps senior citizen customer type', () {
      final verifiedRate = VerifiedFdRate(
        id: 'icici-verified-senior',
        bankId: 'bank-icici',
        bankName: 'ICICI Bank',
        bankShortName: 'ICICI',
        customerType: VerifiedCustomerType.seniorCitizen,
        minTenureDays: 365,
        maxTenureDays: 365,
        minDeposit: 10000,
        interestRate: 7.25,
        isCallable: false,
        compoundingFrequency: CompoundingFrequency.quarterly,
        effectiveFrom: DateTime(2026, 9, 8),
      );

      final fdRate = verifiedRate.toFdRate();
      expect(fdRate.customerType, CustomerType.seniorCitizen);
      expect(fdRate.prematureWithdrawalAllowed, isFalse);
      expect(fdRate.productType, FdProductType.nonCallable);
    });

    test('fromJson is resilient against integer vs num types and null strings', () {
      final json = {
        'id': 'rate-dyn-01',
        'bank_id': 'bank-hdfc',
        'bank_name': 'HDFC Bank',
        'bank_short_name': 'HDFC',
        'customer_type': 'REGULAR',
        'min_tenure_days': 365.0, // double in json
        'max_tenure_days': 730,
        'min_deposit': 5000,
        'interest_rate': 7.1,
        'is_callable': true,
        'compounding_frequency': 'QUARTERLY',
        'effective_from': '2026-09-01T00:00:00Z',
      };

      final rate = VerifiedFdRate.fromJson(json);
      expect(rate.minTenureDays, 365);
      expect(rate.maxTenureDays, 730);
      expect(rate.effectiveFrom.year, 2026);
    });
  });

  group('BankRateRepository Flexible Lookup Tests', () {
    test('getBankById matches by ID, shortName, and full name (case-insensitive)', () {
      // Lookup by ID
      final sbiById = BankRateRepository.getBankById('state_bank_of_india');
      expect(sbiById, isNotNull);
      expect(sbiById!.shortName, 'SBI');

      // Lookup by short name lowercase
      final sbiByShort = BankRateRepository.getBankById('sbi');
      expect(sbiByShort, isNotNull);
      expect(sbiByShort!.name, 'State Bank of India');

      // Lookup by short name uppercase
      final sbiByUpper = BankRateRepository.getBankById('SBI');
      expect(sbiByUpper, isNotNull);
      expect(sbiByUpper!.name, 'State Bank of India');

      // Lookup with bank- prefix
      final sbiWithPrefix = BankRateRepository.getBankById('bank-sbi');
      expect(sbiWithPrefix, isNotNull);
      expect(sbiWithPrefix!.shortName, 'SBI');

      // Lookup ICICI
      final icici = BankRateRepository.getBankById('icici');
      expect(icici, isNotNull);
      expect(icici!.name, 'ICICI Bank');

      // Lookup HDFC
      final hdfc = BankRateRepository.getBankById('hdfc');
      expect(hdfc, isNotNull);
      expect(hdfc!.name, 'HDFC Bank');
    });

    test('getBankById redirects Fincare queries to AU SFB', () {
      final fincare = BankRateRepository.getBankById('fincare');
      expect(fincare, isNotNull);
      expect(fincare!.id, 'au_sfb');
      expect(fincare.shortName, 'AU');
      expect(fincare.name, 'AU SFB');
    });
  });

  group('CompareScreen Source Partition Tests', () {
    testWidgets('renders source switcher and defaults to unverified reference data', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const CompareScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Both segments rendered
      expect(find.byKey(const ValueKey('compare_source_unverified')), findsOneWidget);
      expect(find.byKey(const ValueKey('compare_source_verified')), findsOneWidget);

      // Default view has unverified reference rates
      expect(find.text('All Banks (Reference)'), findsOneWidget);
      expect(find.byType(FdRateCard), findsWidgets);
    });

    testWidgets('tapping Verified Official Rates switches view and shows verified badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const CompareScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap Verified Official Rates
      await tester.tap(find.byKey(const ValueKey('compare_source_verified')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verified rate badge is visible
      expect(find.byType(VerifiedRateBadge), findsWidgets);
    });

    testWidgets('initialSource=verified preselects Verified Official Rates tab', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(child: const CompareScreen(initialSource: 'verified')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verified rate badge is present immediately
      expect(find.byType(VerifiedRateBadge), findsWidgets);
    });
  });
}
