import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/data/bank_data.dart';
import 'package:fincalc_pro/core/data/bank_rate_repository.dart';
import 'package:fincalc_pro/core/models/bank.dart';
import 'package:fincalc_pro/core/models/fd_rate.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
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

  group('Issue #7 — Fincare SFB Amalgamation with AU SFB Bank Data Tests', () {
    test('1. Fincare is NOT in active bank lists', () {
      final allLegacyBanks = BankDataService.getAllBanks();
      expect(
        allLegacyBanks.any((b) => b.name.toLowerCase().contains('fincare')),
        isFalse,
        reason: 'BankDataService.getAllBanks() must not contain Fincare',
      );
      expect(
        allLegacyBanks.any((b) => b.shortName.toLowerCase().contains('fincare')),
        isFalse,
        reason: 'BankDataService.getAllBanks() must not contain Fincare shortName',
      );

      final indianLegacyBanks = BankDataService.getIndianBanks();
      expect(
        indianLegacyBanks.any((b) => b.name.toLowerCase().contains('fincare')),
        isFalse,
        reason: 'BankDataService.getIndianBanks() must not contain Fincare',
      );

      final sfbLegacyBanks = BankDataService.getBanksByType('small_finance');
      expect(
        sfbLegacyBanks.any((b) => b.name.toLowerCase().contains('fincare')),
        isFalse,
        reason: 'BankDataService.getBanksByType("small_finance") must not contain Fincare',
      );

      final allRepoBanks = BankRateRepository.getAllBanks();
      expect(
        allRepoBanks.any((b) => b.name.toLowerCase().contains('fincare') || b.id.contains('fincare')),
        isFalse,
        reason: 'BankRateRepository.getAllBanks() must not contain Fincare',
      );

      final activeRepoBanks = BankRateRepository.getActiveBanks();
      expect(
        activeRepoBanks.any((b) => b.name.toLowerCase().contains('fincare') || b.id.contains('fincare')),
        isFalse,
        reason: 'BankRateRepository.getActiveBanks() must not contain Fincare',
      );

      final sfbRepoBanks = BankRateRepository.getBanksByType(BankType.smallFinance);
      expect(
        sfbRepoBanks.any((b) => b.name.toLowerCase().contains('fincare') || b.id.contains('fincare')),
        isFalse,
        reason: 'BankRateRepository.getBanksByType(BankType.smallFinance) must not contain Fincare',
      );
    });

    test('2. Fincare is NOT present in FD comparison lists, rankings, or top rates', () {
      for (final duration in ['1y', '2y', '3y', '5y']) {
        final topLegacy = BankDataService.getTopBanksByRate(duration, limit: 30);
        expect(
          topLegacy.any((b) => b.name.toLowerCase().contains('fincare')),
          isFalse,
          reason: 'BankDataService.getTopBanksByRate($duration) must not contain Fincare',
        );
      }

      final topRepoRates = BankRateRepository.getTopRates(tenureDays: 365, limit: 30);
      expect(
        topRepoRates.any((r) => r.bankId.contains('fincare')),
        isFalse,
        reason: 'BankRateRepository.getTopRates() must not contain Fincare rate records',
      );

      final comparison = BankRateRepository.compareRates(
        tenureDays: 365,
        customerType: CustomerType.regular,
      );
      for (final item in comparison) {
        final bank = item['bank'] as Bank?;
        final rate = item['rate'] as FdRate?;
        if (bank != null) {
          expect(bank.name.toLowerCase().contains('fincare'), isFalse);
          expect(bank.id.contains('fincare'), isFalse);
        }
        if (rate != null) {
          expect(rate.bankId.contains('fincare'), isFalse);
        }
      }
    });

    test('3. AU Small Finance Bank remains present exactly once with valid data', () {
      final auLegacy = BankDataService.getAllBanks().where((b) => b.name == 'AU SFB').toList();
      expect(auLegacy.length, equals(1), reason: 'AU SFB must exist exactly once in legacy bank list');
      expect(auLegacy.first.website, equals('https://aubank.in'));
      expect(auLegacy.first.customerCare, equals('1800-1200-1500'));
      expect(auLegacy.first.established, equals('1996'));
      expect(auLegacy.first.headquarters, equals('Jaipur'));
      expect(auLegacy.first.fdRates['1y'], equals(7.75));

      final auRepo = BankRateRepository.getAllBanks().where((b) => b.id == 'au_sfb').toList();
      expect(auRepo.length, equals(1), reason: 'AU SFB must exist exactly once in BankRateRepository');
      expect(auRepo.first.name, equals('AU SFB'));
      expect(auRepo.first.officialWebsite, equals('https://aubank.in'));
      expect(auRepo.first.status, equals(BankStatus.active));
    });

    test('4. Fincare identifiers safely resolve to AU SFB', () {
      final fromName = BankDataService.getBankByName('Fincare SFB');
      expect(fromName, isNotNull);
      expect(fromName!.name, equals('AU SFB'));
      expect(fromName.website, equals('https://aubank.in'));

      final fromShort = BankDataService.getBankByName('Fincare');
      expect(fromShort, isNotNull);
      expect(fromShort!.name, equals('AU SFB'));

      final fromFullName = BankDataService.getBankByName('Fincare Small Finance Bank');
      expect(fromFullName, isNotNull);
      expect(fromFullName!.name, equals('AU SFB'));

      final repoBank = BankRateRepository.getBankById('fincare_sfb');
      expect(repoBank, isNotNull);
      expect(repoBank!.id, equals('au_sfb'));
      expect(repoBank.name, equals('AU SFB'));

      final repoBankShort = BankRateRepository.getBankById('fincare');
      expect(repoBankShort, isNotNull);
      expect(repoBankShort!.id, equals('au_sfb'));

      final repoRates = BankRateRepository.getRatesForBank('fincare_sfb');
      expect(repoRates, isNotEmpty);
      expect(repoRates.every((r) => r.bankId == 'au_sfb'), isTrue);
    });

    test('5. Unrelated banks remain intact', () {
      final banks = BankDataService.getAllBanks();
      expect(banks.length, greaterThanOrEqualTo(30));

      final sbi = BankDataService.getBankByName('State Bank of India');
      expect(sbi, isNotNull);

      final hdfc = BankDataService.getBankByName('HDFC Bank');
      expect(hdfc, isNotNull);

      final unity = BankDataService.getBankByName('Unity SFB');
      expect(unity, isNotNull);

      final esaf = BankDataService.getBankByName('ESAF SFB');
      expect(esaf, isNotNull);

      final suryoday = BankDataService.getBankByName('Suryoday SFB');
      expect(suryoday, isNotNull);

      final jana = BankDataService.getBankByName('Jana SFB');
      expect(jana, isNotNull);

      final equitas = BankDataService.getBankByName('Equitas SFB');
      expect(equitas, isNotNull);
    });
  });

  group('Issue #7 — UI & Navigation Tests for AU SFB and Fincare', () {
    testWidgets('BankDetailScreen: Navigating to AU SFB renders AU details', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/bank/AU%20SFB');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('AU SFB'), findsWidgets);
      expect(find.text('https://aubank.in'), findsOneWidget);
      expect(find.text('1800-1200-1500'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('BankDetailScreen: Navigating to Fincare SFB resolves to AU SFB details', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/bank/Fincare%20SFB');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Resolved to AU SFB
      expect(find.text('AU SFB'), findsWidgets);
      expect(find.text('https://aubank.in'), findsOneWidget);
      expect(find.text('https://fincarebank.com'), findsNothing);
      expect(find.text('Fincare SFB'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('CompareScreen: Fincare is not visible, AU SFB is visible', (tester) async {
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

      expect(find.text('Compare FD Rates'), findsOneWidget);
      expect(find.text('Fincare SFB'), findsNothing);
      expect(find.text('Fincare'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
