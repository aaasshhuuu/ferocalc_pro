import 'package:flutter_test/flutter_test.dart';
import 'package:fincalc_pro/core/models/bank.dart';
import 'package:fincalc_pro/core/models/fd_rate.dart';
import 'package:fincalc_pro/core/models/rate_change.dart';
import 'package:fincalc_pro/core/services/rate_freshness_service.dart';
import 'package:fincalc_pro/core/data/bank_rate_repository.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // BANK MODEL SERIALIZATION
  // ═══════════════════════════════════════════════════════════════
  group('Bank Model', () {
    test('Bank serialization roundtrip', () {
      final bank = Bank(
        id: 'sbi',
        name: 'State Bank of India',
        shortName: 'SBI',
        type: BankType.public,
        status: BankStatus.active,
        officialWebsite: 'https://sbi.co.in',
        established: '1955',
        headquarters: 'Mumbai',
      );

      final json = bank.toJson();
      final restored = Bank.fromJson(json);

      expect(restored.id, equals('sbi'));
      expect(restored.name, equals('State Bank of India'));
      expect(restored.shortName, equals('SBI'));
      expect(restored.type, equals(BankType.public));
      expect(restored.status, equals(BankStatus.active));
      expect(restored.officialWebsite, equals('https://sbi.co.in'));
    });

    test('Bank isOperational', () {
      final active = Bank(id: 'a', name: 'A', shortName: 'A', type: BankType.public, status: BankStatus.active);
      final merged = Bank(id: 'b', name: 'B', shortName: 'B', type: BankType.public, status: BankStatus.merged);

      expect(active.isOperational, isTrue);
      expect(merged.isOperational, isFalse);
    });

    test('BankType values', () {
      expect(BankType.values.length, greaterThanOrEqualTo(4));
      expect(BankType.values, contains(BankType.public));
      expect(BankType.values, contains(BankType.private));
      expect(BankType.values, contains(BankType.smallFinance));
      expect(BankType.values, contains(BankType.foreign));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // FD RATE MODEL SERIALIZATION
  // ═══════════════════════════════════════════════════════════════
  group('FdRate Model', () {
    test('FdRate serialization roundtrip', () {
      final rate = FdRate(
        rateId: 'test_1',
        bankId: 'sbi',
        customerType: CustomerType.regular,
        minTenureDays: 365,
        maxTenureDays: 365,
        interestRate: 6.8,
        verificationStatus: VerificationStatus.pendingReview,
        minDeposit: 1000,
        sourceUrl: 'https://sbi.co.in',
      );

      final json = rate.toJson();
      final restored = FdRate.fromJson(json);

      expect(restored.rateId, equals('test_1'));
      expect(restored.bankId, equals('sbi'));
      expect(restored.customerType, equals(CustomerType.regular));
      expect(restored.minTenureDays, equals(365));
      expect(restored.interestRate, equals(6.8));
      expect(restored.verificationStatus, equals(VerificationStatus.pendingReview));
    });

    test('FdRate appliesToTenure', () {
      final rate = FdRate(
        rateId: 'test',
        bankId: 'sbi',
        customerType: CustomerType.regular,
        minTenureDays: 180,
        maxTenureDays: 365,
        interestRate: 6.5,
        verificationStatus: VerificationStatus.pendingReview,
      );

      expect(rate.appliesToTenure(200), isTrue);
      expect(rate.appliesToTenure(180), isTrue);
      expect(rate.appliesToTenure(365), isTrue);
      expect(rate.appliesToTenure(100), isFalse);
      expect(rate.appliesToTenure(400), isFalse);
    });

    test('FdRate appliesToAmount', () {
      final rate = FdRate(
        rateId: 'test',
        bankId: 'sbi',
        customerType: CustomerType.regular,
        minTenureDays: 365,
        maxTenureDays: 365,
        interestRate: 6.5,
        minDeposit: 10000,
        maxDeposit: 200000000,
        verificationStatus: VerificationStatus.pendingReview,
      );

      expect(rate.appliesToAmount(50000), isTrue);
      expect(rate.appliesToAmount(5000), isFalse);
    });

    test('VerificationStatus values', () {
      expect(VerificationStatus.values, contains(VerificationStatus.verified));
      expect(VerificationStatus.values, contains(VerificationStatus.pendingReview));
      expect(VerificationStatus.values, contains(VerificationStatus.stale));
      expect(VerificationStatus.values, contains(VerificationStatus.suspicious));
      expect(VerificationStatus.values, contains(VerificationStatus.rejected));
      expect(VerificationStatus.values, contains(VerificationStatus.archived));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // RATE CHANGE DETECTION
  // ═══════════════════════════════════════════════════════════════
  group('Rate Change', () {
    test('Serialization roundtrip', () {
      final now = DateTime.now();
      final change = RateChange(
        changeId: 'c1',
        rateId: 'r1',
        bankId: 'sbi',
        previousRate: 6.50,
        newRate: 7.00,
        changedAt: now,
      );

      final json = change.toJson();
      final restored = RateChange.fromJson(json);

      expect(restored.changeId, equals('c1'));
      expect(restored.previousRate, equals(6.50));
      expect(restored.newRate, equals(7.00));
      expect(restored.absoluteChange, closeTo(0.50, 0.01));
    });

    test('Small change not suspicious (7.80→8.00 = 0.20pp)', () {
      final change = RateChange(
        changeId: 't1', rateId: 'r1', bankId: 'b1',
        previousRate: 7.80, newRate: 8.00, changedAt: DateTime.now(),
      );
      expect(change.absoluteChange, closeTo(0.20, 0.01));
      expect(change.isSuspicious, isFalse);
    });

    test('Large change is suspicious (7.80→15.50 = 7.70pp)', () {
      final change = RateChange(
        changeId: 't2', rateId: 'r1', bankId: 'b1',
        previousRate: 7.80, newRate: 15.50, changedAt: DateTime.now(),
      );
      expect(change.absoluteChange, closeTo(7.70, 0.01));
      expect(change.isSuspicious, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // FRESHNESS SERVICE
  // ═══════════════════════════════════════════════════════════════
  group('Rate Freshness', () {
    test('Null verifiedAt returns unverified', () {
      final result = RateFreshnessService.getFreshness(null);
      expect(result, equals(RateFreshness.unverified));
      expect(result.label, equals('Unverified'));
    });

    test('Recently verified (within 2 days)', () {
      final recent = DateTime.now().subtract(const Duration(hours: 12));
      final result = RateFreshnessService.getFreshness(recent);
      expect(result, equals(RateFreshness.recentlyVerified));
    });

    test('Verified recently (3-7 days)', () {
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      final result = RateFreshnessService.getFreshness(fiveDaysAgo);
      expect(result, equals(RateFreshness.verifiedRecently));
    });

    test('Older data (8-30 days)', () {
      final fifteenDaysAgo = DateTime.now().subtract(const Duration(days: 15));
      final result = RateFreshnessService.getFreshness(fifteenDaysAgo);
      expect(result, equals(RateFreshness.olderData));
    });

    test('Verification required (30+ days)', () {
      final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60));
      final result = RateFreshnessService.getFreshness(sixtyDaysAgo);
      expect(result, equals(RateFreshness.verificationRequired));
    });

    test('Pending review rate', () {
      final rate = FdRate(
        rateId: 'test', bankId: 'sbi',
        customerType: CustomerType.regular,
        minTenureDays: 365, maxTenureDays: 365,
        interestRate: 6.8,
        verificationStatus: VerificationStatus.pendingReview,
      );
      final result = RateFreshnessService.getRateFreshness(rate);
      expect(result, equals(RateFreshness.pendingReview));
      expect(result.label, equals('Pending review'));
    });

    test('Suspicious rate', () {
      final rate = FdRate(
        rateId: 'test', bankId: 'sbi',
        customerType: CustomerType.regular,
        minTenureDays: 365, maxTenureDays: 365,
        interestRate: 15.0,
        verificationStatus: VerificationStatus.suspicious,
      );
      final result = RateFreshnessService.getRateFreshness(rate);
      expect(result, equals(RateFreshness.suspicious));
    });

    test('Every RateFreshness has a label', () {
      for (final freshness in RateFreshness.values) {
        expect(freshness.label, isNotEmpty);
        expect(freshness.icon, isNotEmpty);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // BANK RATE REPOSITORY
  // ═══════════════════════════════════════════════════════════════
  group('BankRateRepository', () {
    test('getAllBanks returns non-empty list', () {
      final banks = BankRateRepository.getAllBanks();
      expect(banks, isNotEmpty);
      expect(banks.length, greaterThanOrEqualTo(28)); // 28+ Indian banks
    });

    test('All banks have valid IDs', () {
      final banks = BankRateRepository.getAllBanks();
      for (final bank in banks) {
        expect(bank.id, isNotEmpty);
        expect(bank.name, isNotEmpty);
        expect(bank.type, isNotNull);
        expect(bank.status, equals(BankStatus.active));
      }
    });

    test('getRatesForBank returns rates', () {
      final banks = BankRateRepository.getAllBanks();
      final rates = BankRateRepository.getRatesForBank(banks.first.id);
      expect(rates, isNotEmpty);
    });

    test('All rates are PENDING_REVIEW (no verified data)', () {
      final banks = BankRateRepository.getAllBanks();
      for (final bank in banks) {
        final rates = BankRateRepository.getRatesForBank(bank.id);
        for (final rate in rates) {
          expect(rate.verificationStatus, equals(VerificationStatus.pendingReview),
              reason: 'Rate ${rate.rateId} should be PENDING_REVIEW');
        }
      }
    });

    test('No rate has verifiedAt timestamp', () {
      final banks = BankRateRepository.getAllBanks();
      for (final bank in banks) {
        final rates = BankRateRepository.getRatesForBank(bank.id);
        for (final rate in rates) {
          expect(rate.verifiedAt, isNull,
              reason: 'Unverified rate ${rate.rateId} should not have verifiedAt');
        }
      }
    });

    test('findRates filters by customer type', () {
      final banks = BankRateRepository.getAllBanks();
      final regularRates = BankRateRepository.findRates(
        bankId: banks.first.id,
        customerType: CustomerType.regular,
      );
      final seniorRates = BankRateRepository.findRates(
        bankId: banks.first.id,
        customerType: CustomerType.seniorCitizen,
      );

      for (final r in regularRates) {
        expect(r.customerType, equals(CustomerType.regular));
      }
      for (final r in seniorRates) {
        expect(r.customerType, equals(CustomerType.seniorCitizen));
      }
    });

    test('Senior citizen rates are higher than regular', () {
      final banks = BankRateRepository.getAllBanks();
      final regular = BankRateRepository.findRates(
        bankId: banks.first.id,
        customerType: CustomerType.regular,
        tenureDays: 365,
      );
      final senior = BankRateRepository.findRates(
        bankId: banks.first.id,
        customerType: CustomerType.seniorCitizen,
        tenureDays: 365,
      );

      if (regular.isNotEmpty && senior.isNotEmpty) {
        expect(senior.first.interestRate, greaterThan(regular.first.interestRate));
      }
    });

    test('getTopRates returns sorted rates', () {
      final topRates = BankRateRepository.getTopRates(tenureDays: 365, limit: 5);
      expect(topRates.length, lessThanOrEqualTo(5));
      if (topRates.length >= 2) {
        expect(topRates[0].interestRate, greaterThanOrEqualTo(topRates[1].interestRate));
      }
    });

    test('findRates with includeUnverified=false returns empty', () {
      final verified = BankRateRepository.findRates(includeUnverified: false);
      expect(verified, isEmpty, reason: 'No rates should be verified');
    });

    test('compareRates returns structured data', () {
      final comparison = BankRateRepository.compareRates(
        tenureDays: 365,
        customerType: CustomerType.regular,
      );
      expect(comparison, isNotEmpty);
      for (final entry in comparison) {
        expect(entry['bank'], isNotNull);
        expect(entry['rate'], isNotNull);
        expect(entry['freshness'], isNotNull);
      }
    });
  });
}
