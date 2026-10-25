// FeroCalc Flutter Tests — Special Scheme Qualification & UI Disclosure
//
// Tests:
// 1. FdRate model special scheme properties & serialization
// 2. VerifiedFdRate.toFdRate() lossless metadata preservation
// 3. FdRateCard special scheme badge & disclosure rendering
// 4. Standard rate regression guard (unaffected)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fincalc_pro/core/models/bank.dart';
import 'package:fincalc_pro/core/models/fd_rate.dart';
import 'package:fincalc_pro/core/models/verified_fd_rate.dart';
import 'package:fincalc_pro/core/widgets/fd_rate_card.dart';

void main() {
  group('FdRate & VerifiedFdRate Special Scheme Model Tests', () {
    test('FdRate.isSpecialScheme is true when rateCategory is SPECIAL_SCHEME', () {
      final rate = FdRate(
        rateId: 'r1',
        bankId: 'sbi',
        customerType: CustomerType.seniorCitizen,
        minTenureDays: 1825,
        maxTenureDays: 3650,
        interestRate: 7.05,
        rateCategory: 'SPECIAL_SCHEME',
        schemeName: 'SBI We-Care',
        qualificationNotes: "* Including additional premium of 50 bps under 'SBI We-care' deposit scheme.",
      );

      expect(rate.isSpecialScheme, isTrue);
      expect(rate.schemeName, 'SBI We-Care');
      expect(rate.qualificationNotes, contains('SBI We-care'));
    });

    test('FdRate.isSpecialScheme is false for standard card rate', () {
      final rate = FdRate(
        rateId: 'r2',
        bankId: 'sbi',
        customerType: CustomerType.seniorCitizen,
        minTenureDays: 365,
        maxTenureDays: 729,
        interestRate: 6.75,
        rateCategory: 'STANDARD',
        schemeName: null,
      );

      expect(rate.isSpecialScheme, isFalse);
      expect(rate.schemeName, isNull);
    });

    test('FdRate toJson and fromJson round-trips special scheme fields', () {
      final original = FdRate(
        rateId: 'r1',
        bankId: 'sbi',
        customerType: CustomerType.seniorCitizen,
        minTenureDays: 1825,
        maxTenureDays: 3650,
        interestRate: 7.05,
        rateCategory: 'SPECIAL_SCHEME',
        schemeName: 'SBI We-Care',
        qualificationNotes: 'Includes additional 50 bps',
      );

      final json = original.toJson();
      expect(json['rateCategory'], 'SPECIAL_SCHEME');
      expect(json['schemeName'], 'SBI We-Care');
      expect(json['qualificationNotes'], 'Includes additional 50 bps');

      final deserialized = FdRate.fromJson(json);
      expect(deserialized.isSpecialScheme, isTrue);
      expect(deserialized.rateCategory, 'SPECIAL_SCHEME');
      expect(deserialized.schemeName, 'SBI We-Care');
      expect(deserialized.qualificationNotes, 'Includes additional 50 bps');
    });

    test('VerifiedFdRate.toFdRate() losslessly preserves scheme metadata', () {
      final verifiedRate = VerifiedFdRate(
        id: 'v_sbi_16',
        bankId: 'sbi',
        bankName: 'State Bank of India',
        bankShortName: 'SBI',
        bankSourceDomain: 'sbi.co.in',
        customerType: VerifiedCustomerType.seniorCitizen,
        minTenureDays: 1825,
        maxTenureDays: 3650,
        minDeposit: 1000,
        maxDeposit: 29999999,
        interestRate: 7.05,
        isCallable: true,
        compoundingFrequency: CompoundingFrequency.quarterly,
        effectiveFrom: DateTime(2025, 12, 15),
        sourceUrl: 'https://sbi.co.in/rates',
        rateCategory: RateCategory.specialScheme,
        schemeName: 'SBI We-Care',
        reviewNotes: "* Including additional premium of 50 bps under 'SBI We-care' deposit scheme.",
      );

      final fdRate = verifiedRate.toFdRate();
      expect(fdRate.isSpecialScheme, isTrue);
      expect(fdRate.rateCategory, 'SPECIAL_SCHEME');
      expect(fdRate.schemeName, 'SBI We-Care');
      expect(fdRate.qualificationNotes, contains('SBI We-care'));
      expect(fdRate.interestRate, 7.05);
    });
  });

  group('FdRateCard Special Scheme UI Disclosure Widget Tests', () {
    final testBank = Bank(
      id: 'sbi',
      name: 'State Bank of India',
      shortName: 'SBI',
      type: BankType.public,
      status: BankStatus.active,
      officialWebsite: 'https://sbi.co.in',
    );

    testWidgets('FdRateCard displays special scheme badge and qualification disclosure', (tester) async {
      final specialRate = FdRate(
        rateId: 'r_wecare',
        bankId: 'sbi',
        customerType: CustomerType.seniorCitizen,
        minTenureDays: 1825,
        maxTenureDays: 3650,
        interestRate: 7.05,
        verificationStatus: VerificationStatus.verified,
        rateCategory: 'SPECIAL_SCHEME',
        schemeName: 'SBI We-Care',
        qualificationNotes: "* Including additional premium of 50 bps under 'SBI We-care' deposit scheme.",
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FdRateCard(
              bank: testBank,
              rate: specialRate,
            ),
          ),
        ),
      );

      // Verify Special Scheme badge is present
      expect(find.byKey(const ValueKey('special_scheme_badge')), findsOneWidget);
      expect(find.text('Special Scheme: SBI We-Care'), findsOneWidget);

      // Verify rate value and disclosure
      expect(find.text('7.05% p.a.'), findsOneWidget);
      expect(find.text('Senior Citizen \u2022 Scheme Terms Apply'), findsOneWidget);
      expect(find.text("* Including additional premium of 50 bps under 'SBI We-care' deposit scheme."), findsOneWidget);
    });

    testWidgets('FdRateCard standard rate does NOT display special scheme badge', (tester) async {
      final standardRate = FdRate(
        rateId: 'r_std',
        bankId: 'sbi',
        customerType: CustomerType.seniorCitizen,
        minTenureDays: 365,
        maxTenureDays: 729,
        interestRate: 6.75,
        verificationStatus: VerificationStatus.verified,
        rateCategory: 'STANDARD',
        schemeName: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FdRateCard(
              bank: testBank,
              rate: standardRate,
            ),
          ),
        ),
      );

      // Verify Special Scheme badge is NOT present
      expect(find.byKey(const ValueKey('special_scheme_badge')), findsNothing);
      expect(find.text('Special Scheme: SBI We-Care'), findsNothing);
      expect(find.text('Senior Citizen'), findsOneWidget);
    });
  });
}
