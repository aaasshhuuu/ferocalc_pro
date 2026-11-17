import 'package:fincalc_pro/core/models/discovery_models.dart';
import 'package:fincalc_pro/core/models/verified_fd_rate.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart' hide CompoundingFrequency;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group 1: FdDiscoveryCriteria Validation & Conversions', () {
    test('Validates normal investment criteria successfully', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 150000,
        tenureUnit: TenureUnit.years,
        tenureValue: 2,
        customerCategory: CustomerCategory.regular,
      );

      expect(criteria.validate(), isNull);
      expect(criteria.tenureInDays, 730);
      expect(criteria.tenureInYears, 2.0);
      expect(criteria.formattedTenureLabel, '2 Years');
    });

    test('Rejects zero or negative deposit amounts', () {
      const criteriaZero = FdDiscoveryCriteria(depositAmount: 0);
      expect(criteriaZero.validate(), contains('greater than zero'));

      const criteriaNeg = FdDiscoveryCriteria(depositAmount: -5000);
      expect(criteriaNeg.validate(), contains('greater than zero'));
    });

    test('Rejects tenure less than 7 days for Days unit', () {
      const criteria = FdDiscoveryCriteria(
        tenureUnit: TenureUnit.days,
        tenureValue: 5,
      );
      expect(criteria.validate(), contains('Minimum FD tenure across Indian banks is 7 days'));
    });

    test('Rejects tenure greater than 10 years (3,650 days)', () {
      const criteriaDays = FdDiscoveryCriteria(
        tenureUnit: TenureUnit.days,
        tenureValue: 4000,
      );
      expect(criteriaDays.validate(), contains('Maximum FD tenure'));

      const criteriaYears = FdDiscoveryCriteria(
        tenureUnit: TenureUnit.years,
        tenureValue: 12,
      );
      expect(criteriaYears.validate(), contains('Maximum FD tenure'));
    });

    test('Accurately converts Months unit to fractional years and calendar components', () {
      const criteria = FdDiscoveryCriteria(
        tenureUnit: TenureUnit.months,
        tenureValue: 18,
      );

      expect(criteria.validate(), isNull);
      expect(criteria.tenureInYears, 1.5);
      final cal = criteria.calendarComponents;
      expect(cal['years'], 1);
      expect(cal['months'], 6);
      expect(cal['days'], 0);
    });
  });

  group('Group 2: FdDiscoveryEngine — Deposit Boundary & Eligibility Filtering', () {
    final anchor = DateTime(2026, 11, 12);

    final sbiStandardRate = VerifiedFdRate(
      id: 'rate-sbi-1y',
      bankId: 'b-sbi',
      bankName: 'State Bank of India',
      bankShortName: 'SBI',
      customerType: VerifiedCustomerType.regular,
      minTenureDays: 365,
      maxTenureDays: 729,
      minDeposit: 1000,
      maxDeposit: 20000000, // 2 Crores
      interestRate: 6.80,
      isCallable: true,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2026, 1, 1),
    );

    final pnbHighNetWorthRate = VerifiedFdRate(
      id: 'rate-pnb-bulk',
      bankId: 'b-pnb',
      bankName: 'Punjab National Bank',
      bankShortName: 'PNB',
      customerType: VerifiedCustomerType.regular,
      minTenureDays: 365,
      maxTenureDays: 729,
      minDeposit: 20000001, // > 2 Crores (Bulk Deposit)
      maxDeposit: 100000000,
      interestRate: 7.25,
      isCallable: true,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2026, 1, 1),
    );

    test('Matches deposit within slab min and max boundaries', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 500000, // 5 Lakhs
        tenureUnit: TenureUnit.years,
        tenureValue: 1,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [sbiStandardRate, pnbHighNetWorthRate],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches.length, 1);
      expect(matches.first.rate.id, 'rate-sbi-1y');
      expect(matches.first.bankShortName, 'SBI');
    });

    test('Excludes retail deposit when amount is below minimum deposit boundary', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 500, // Below 1,000 min
        tenureUnit: TenureUnit.years,
        tenureValue: 1,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [sbiStandardRate],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches, isEmpty);
    });

    test('Matches high-net-worth deposit only when exceeding 2 Crore bulk threshold', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 25000000, // 2.5 Crores
        tenureUnit: TenureUnit.years,
        tenureValue: 1,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [sbiStandardRate, pnbHighNetWorthRate],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches.length, 1);
      expect(matches.first.rate.id, 'rate-pnb-bulk');
      expect(matches.first.bankShortName, 'PNB');
    });
  });

  group('Group 3: FdDiscoveryEngine — Tenure Domain Matching (DAYS & CALENDAR)', () {
    final anchor = DateTime(2026, 11, 12);

    final daysSbiRate = VerifiedFdRate(
      id: 'rate-sbi-days',
      bankId: 'b-sbi',
      bankName: 'State Bank of India',
      bankShortName: 'SBI',
      customerType: VerifiedCustomerType.regular,
      tenureDomain: TenureDomain.days,
      minTenureDays: 211,
      maxTenureDays: 364,
      minDeposit: 1000,
      interestRate: 6.50,
      isCallable: true,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2026, 1, 1),
      sourceTenureText: '211 days to less than 1 year',
    );

    final calendarHdfcRate = VerifiedFdRate(
      id: 'rate-hdfc-cal',
      bankId: 'b-hdfc',
      bankName: 'HDFC Bank',
      bankShortName: 'HDFC',
      customerType: VerifiedCustomerType.regular,
      tenureDomain: TenureDomain.calendar,
      minYears: 1,
      minMonths: 0,
      minDaysCal: 0,
      minOperator: BoundaryOperator.gte,
      maxYears: 1,
      maxMonths: 3,
      maxDaysCal: 0,
      maxOperator: BoundaryOperator.lte,
      minDeposit: 5000,
      interestRate: 7.10,
      isCallable: true,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2026, 1, 1),
      sourceTenureText: '1 Year to 15 Months',
    );

    test('DAYS domain matches exact day criteria in range', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.days,
        tenureValue: 240, // Inside 211-364
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [daysSbiRate, calendarHdfcRate],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches.length, 1);
      expect(matches.first.rate.id, 'rate-sbi-days');
      expect(matches.first.matchingTenureText, '211 days to less than 1 year');
    });

    test('CALENDAR domain matches 1 Year tenure criteria', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.years,
        tenureValue: 1,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [daysSbiRate, calendarHdfcRate],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches.length, 1);
      expect(matches.first.rate.id, 'rate-hdfc-cal');
      expect(matches.first.matchingTenureText, '1 Year to 15 Months');
    });

    test('CALENDAR domain matches 14 months tenure criteria', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.months,
        tenureValue: 14, // 1Y 2M, within 1Y to 1Y 3M
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [daysSbiRate, calendarHdfcRate],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches.length, 1);
      expect(matches.first.rate.id, 'rate-hdfc-cal');
    });

    test('Excludes rates outside tenure bounds', () {
      const criteriaShort = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.days,
        tenureValue: 30, // Way below 211
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [daysSbiRate, calendarHdfcRate],
        criteria: criteriaShort,
        anchorDate: anchor,
      );

      expect(matches, isEmpty);
    });
  });

  group('Group 4: Customer Category, Liquidity & Expiry Filtering', () {
    final anchor = DateTime(2026, 11, 12);

    final regularCallable = VerifiedFdRate(
      id: 'reg-callable',
      bankId: 'b-icici',
      bankName: 'ICICI Bank',
      bankShortName: 'ICICI',
      customerType: VerifiedCustomerType.regular,
      minTenureDays: 365,
      maxTenureDays: 730,
      minDeposit: 10000,
      interestRate: 6.70,
      isCallable: true,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2026, 1, 1),
    );

    final seniorCallable = VerifiedFdRate(
      id: 'sr-callable',
      bankId: 'b-icici',
      bankName: 'ICICI Bank',
      bankShortName: 'ICICI',
      customerType: VerifiedCustomerType.seniorCitizen,
      minTenureDays: 365,
      maxTenureDays: 730,
      minDeposit: 10000,
      interestRate: 7.20,
      isCallable: true,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2026, 1, 1),
    );

    final regularNonCallable = VerifiedFdRate(
      id: 'reg-non-callable',
      bankId: 'b-axis',
      bankName: 'Axis Bank',
      bankShortName: 'AXIS',
      customerType: VerifiedCustomerType.regular,
      minTenureDays: 365,
      maxTenureDays: 730,
      minDeposit: 10000,
      interestRate: 7.15,
      isCallable: false,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2026, 1, 1),
    );

    final expiredRate = VerifiedFdRate(
      id: 'expired-rate',
      bankId: 'b-bob',
      bankName: 'Bank of Baroda',
      bankShortName: 'BOB',
      customerType: VerifiedCustomerType.regular,
      minTenureDays: 365,
      maxTenureDays: 730,
      minDeposit: 10000,
      interestRate: 7.50,
      isCallable: true,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2025, 1, 1),
      effectiveUntil: DateTime(2026, 1, 1), // Expired before anchor 2026-11-12
    );

    test('Customer category Senior Citizen selects only senior citizen rates', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.years,
        tenureValue: 1,
        customerCategory: CustomerCategory.seniorCitizen,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [regularCallable, seniorCallable, regularNonCallable, expiredRate],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches.length, 1);
      expect(matches.first.rate.id, 'sr-callable');
      expect(matches.first.interestRate, 7.20);
    });

    test('Callable preference: callableOnly excludes locked non-callable products', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.years,
        tenureValue: 1,
        customerCategory: CustomerCategory.regular,
        callablePreference: CallablePreference.callableOnly,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [regularCallable, seniorCallable, regularNonCallable, expiredRate],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches.length, 1);
      expect(matches.first.rate.id, 'reg-callable');
      expect(matches.first.isCallable, isTrue);
    });

    test('Callable preference: nonCallableOnly matches only non-callable products', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.years,
        tenureValue: 1,
        customerCategory: CustomerCategory.regular,
        callablePreference: CallablePreference.nonCallableOnly,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [regularCallable, seniorCallable, regularNonCallable, expiredRate],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches.length, 1);
      expect(matches.first.rate.id, 'reg-non-callable');
      expect(matches.first.isCallable, isFalse);
    });

    test('Excludes expired rates automatically', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.years,
        tenureValue: 1,
        customerCategory: CustomerCategory.regular,
        callablePreference: CallablePreference.any,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [expiredRate],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches, isEmpty);
    });
  });

  group('Group 5: Mathematical Accuracy & Ranking', () {
    final anchor = DateTime(2026, 11, 12);

    final rateA = VerifiedFdRate(
      id: 'rate-a',
      bankId: 'b-sbi',
      bankName: 'State Bank of India',
      bankShortName: 'SBI',
      customerType: VerifiedCustomerType.regular,
      minTenureDays: 365,
      maxTenureDays: 730,
      minDeposit: 1000,
      interestRate: 6.80,
      isCallable: true,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2026, 1, 1),
    );

    final rateB = VerifiedFdRate(
      id: 'rate-b',
      bankId: 'b-canara',
      bankName: 'Canara Bank',
      bankShortName: 'CANARA',
      customerType: VerifiedCustomerType.regular,
      minTenureDays: 365,
      maxTenureDays: 730,
      minDeposit: 1000,
      interestRate: 7.25,
      isCallable: true,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2026, 1, 1),
    );

    final rateC = VerifiedFdRate(
      id: 'rate-c',
      bankId: 'b-axis',
      bankName: 'Axis Bank',
      bankShortName: 'AXIS',
      customerType: VerifiedCustomerType.regular,
      minTenureDays: 365,
      maxTenureDays: 730,
      minDeposit: 1000,
      interestRate: 7.10,
      isCallable: true,
      compoundingFrequency: CompoundingFrequency.quarterly,
      effectiveFrom: DateTime(2026, 1, 1),
    );

    test('Computes quarterly compounding maturity exactly matching FinancialMath', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.years,
        tenureValue: 2,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [rateB],
        criteria: criteria,
        anchorDate: anchor,
      );

      expect(matches.length, 1);
      final match = matches.first;

      final expectedMaturity = FinancialMath.calculateFDMaturity(
        principal: 100000,
        annualRate: 7.25,
        years: 2.0,
        compoundingFrequency: 4,
      );

      expect(match.estimatedMaturity, closeTo(expectedMaturity, 0.001));
      expect(match.estimatedInterest, closeTo(expectedMaturity - 100000, 0.001));
      // Manual verification: A = 100000 * (1 + 0.0725 / 4)^(8) ≈ 115453.95
      expect(match.estimatedMaturity, closeTo(115453.95, 0.5));
    });

    test('Correctly sorts by Highest Return (Maturity Amount)', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.years,
        tenureValue: 1,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [rateA, rateB, rateC],
        criteria: criteria,
        anchorDate: anchor,
      );

      final sorted = FdDiscoveryEngine.sortMatches(matches, FdSortOption.maturityAmount);

      expect(sorted[0].rate.id, 'rate-b'); // 7.25%
      expect(sorted[1].rate.id, 'rate-c'); // 7.10%
      expect(sorted[2].rate.id, 'rate-a'); // 6.80%
    });

    test('Correctly sorts by Bank Name (A-Z)', () {
      const criteria = FdDiscoveryCriteria(
        depositAmount: 100000,
        tenureUnit: TenureUnit.years,
        tenureValue: 1,
      );

      final matches = FdDiscoveryEngine.findMatches(
        rates: [rateA, rateB, rateC],
        criteria: criteria,
        anchorDate: anchor,
      );

      final sorted = FdDiscoveryEngine.sortMatches(matches, FdSortOption.bankName);

      expect(sorted[0].bankName, 'Axis Bank');
      expect(sorted[1].bankName, 'Canara Bank');
      expect(sorted[2].bankName, 'State Bank of India');
    });
  });
}
