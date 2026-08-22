import 'package:flutter_test/flutter_test.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/core/models/rate_change.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // EMI CALCULATIONS
  // ═══════════════════════════════════════════════════════════════
  group('EMI Calculator', () {
    test('Standard EMI calculation', () {
      final emi = FinancialMath.calculateEMI(
        principal: 1000000,
        annualRate: 8.5,
        months: 120,
      );
      expect(emi, closeTo(12399, 1));
    });

    test('Zero interest rate returns simple division', () {
      final emi = FinancialMath.calculateEMI(
        principal: 1200000,
        annualRate: 0,
        months: 12,
      );
      expect(emi, equals(100000));
    });

    test('Zero months returns 0', () {
      final emi = FinancialMath.calculateEMI(
        principal: 1000000,
        annualRate: 8.5,
        months: 0,
      );
      expect(emi, equals(0));
    });

    test('Small loan amount', () {
      final emi = FinancialMath.calculateEMI(
        principal: 10000,
        annualRate: 12,
        months: 12,
      );
      expect(emi, closeTo(888.49, 0.1));
    });

    test('Large loan amount is finite', () {
      final emi = FinancialMath.calculateEMI(
        principal: 50000000,
        annualRate: 9.0,
        months: 240,
      );
      expect(emi, greaterThan(0));
      expect(emi, isNot(isNaN));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // AMORTIZATION SCHEDULE
  // ═══════════════════════════════════════════════════════════════
  group('Amortization Schedule', () {
    test('Schedule has correct number of entries', () {
      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: 1000000,
        annualRate: 10,
        months: 12,
      );
      expect(schedule.length, equals(12));
    });

    test('Final balance is approximately zero', () {
      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: 1000000,
        annualRate: 10,
        months: 12,
      );
      expect(schedule.last['balance']!, closeTo(0, 1));
    });

    test('Each EMI is consistent', () {
      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: 500000,
        annualRate: 8,
        months: 60,
      );
      final emi = schedule.first['emi']!;
      for (final entry in schedule) {
        expect(entry['emi'], closeTo(emi, 0.01));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // FD CALCULATIONS
  // ═══════════════════════════════════════════════════════════════
  group('FD Calculator', () {
    test('FD maturity with quarterly compounding', () {
      final maturity = FinancialMath.calculateFDMaturity(
        principal: 100000,
        annualRate: 7.0,
        years: 1,
        compoundingFrequency: 4,
      );
      expect(maturity, closeTo(107186, 1));
    });

    test('FD with zero interest returns principal', () {
      final maturity = FinancialMath.calculateFDMaturity(
        principal: 100000,
        annualRate: 0,
        years: 5,
      );
      expect(maturity, equals(100000));
    });

    test('FD interest calculation', () {
      final interest = FinancialMath.calculateFDInterest(
        principal: 100000,
        annualRate: 7.0,
        years: 1,
        compoundingFrequency: 4,
      );
      expect(interest, closeTo(7186, 1));
    });

    test('Multi-year FD is finite and greater than principal', () {
      final maturity = FinancialMath.calculateFDMaturity(
        principal: 500000,
        annualRate: 7.5,
        years: 5,
        compoundingFrequency: 4,
      );
      expect(maturity, greaterThan(500000));
      expect(maturity, isNot(isNaN));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // SIP CALCULATIONS
  // ═══════════════════════════════════════════════════════════════
  group('SIP Calculator', () {
    test('Standard SIP calculation', () {
      final futureValue = FinancialMath.calculateSIPMaturity(
        monthlyInvestment: 10000,
        annualReturn: 12,
        months: 120,
      );
      expect(futureValue, closeTo(2323391, 1000));
    });

    test('Zero return rate sums all deposits', () {
      final futureValue = FinancialMath.calculateSIPMaturity(
        monthlyInvestment: 10000,
        annualReturn: 0,
        months: 12,
      );
      expect(futureValue, closeTo(120000, 1));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // RD CALCULATIONS
  // ═══════════════════════════════════════════════════════════════
  group('RD Calculator', () {
    test('Standard RD maturity exceeds total deposits', () {
      final maturity = FinancialMath.calculateRDMaturity(
        monthlyDeposit: 5000,
        annualRate: 6.5,
        months: 60,
      );
      expect(maturity, greaterThan(300000));
      expect(maturity, isNot(isNaN));
    });

    test('RD interest is positive', () {
      final interest = FinancialMath.calculateRDInterest(
        monthlyDeposit: 5000,
        annualRate: 6.5,
        months: 60,
      );
      expect(interest, greaterThan(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // PPF CALCULATIONS
  // ═══════════════════════════════════════════════════════════════
  group('PPF Calculator', () {
    test('PPF maturity over 15 years', () {
      final result = FinancialMath.calculatePPF(
        yearlyDeposit: 150000,
        annualRate: 7.1,
        years: 15,
      );
      expect(result['maturityValue']!, greaterThan(2250000));
      expect(result['totalDeposit']!, equals(2250000));
      expect(result['totalInterest']!, greaterThan(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // CAGR
  // ═══════════════════════════════════════════════════════════════
  group('CAGR Calculator', () {
    test('Standard CAGR', () {
      final cagr = FinancialMath.calculateCAGR(
        initialValue: 10000,
        finalValue: 20000,
        years: 5,
      );
      expect(cagr, closeTo(14.87, 0.1));
    });

    test('No growth returns 0', () {
      final cagr = FinancialMath.calculateCAGR(
        initialValue: 10000,
        finalValue: 10000,
        years: 5,
      );
      expect(cagr, closeTo(0, 0.01));
    });

    test('Negative growth returns negative CAGR', () {
      final cagr = FinancialMath.calculateCAGR(
        initialValue: 20000,
        finalValue: 10000,
        years: 5,
      );
      expect(cagr, lessThan(0));
    });

    test('Zero initial value returns 0', () {
      final cagr = FinancialMath.calculateCAGR(
        initialValue: 0,
        finalValue: 10000,
        years: 5,
      );
      expect(cagr, equals(0));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // LUMPSUM
  // ═══════════════════════════════════════════════════════════════
  group('Lumpsum Calculator', () {
    test('Lumpsum growth', () {
      final fv = FinancialMath.calculateLumpsum(
        principal: 100000,
        annualReturn: 12,
        years: 10,
      );
      expect(fv, closeTo(310585, 10));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // REVERSE CALCULATIONS
  // ═══════════════════════════════════════════════════════════════
  group('Reverse Calculators', () {
    test('Loan amount from EMI', () {
      final amount = FinancialMath.calculateLoanAmount(
        emi: 12399,
        annualRate: 8.5,
        months: 120,
      );
      expect(amount, closeTo(1000000, 1000));
    });

    test('Loan tenure from EMI', () {
      final months = FinancialMath.calculateLoanTenure(
        principal: 1000000,
        annualRate: 8.5,
        emi: 12399,
      );
      expect(months, equals(120));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // TENURE CONVERSION
  // ═══════════════════════════════════════════════════════════════
  group('Tenure Conversion', () {
    test('Combined tenure to years', () {
      final years = FinancialMath.combinedTenureToYears(
        years: 1,
        months: 6,
        days: 15,
      );
      expect(years, closeTo(1.541, 0.01));
    });

    test('Combined tenure to days', () {
      final days = FinancialMath.combinedTenureToDays(
        years: 1,
        months: 0,
        days: 0,
      );
      expect(days, equals(365));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // RATE CHANGE DETECTION
  // ═══════════════════════════════════════════════════════════════
  group('Rate Change Detection', () {
    test('Small rate change is not suspicious', () {
      final change = RateChange(
        changeId: 'test1',
        rateId: 'r1',
        bankId: 'sbi',
        previousRate: 7.80,
        newRate: 8.00,
        changedAt: DateTime.now(),
      );
      expect(change.absoluteChange, closeTo(0.20, 0.01));
      expect(change.isSuspicious, isFalse);
    });

    test('Large rate change is suspicious', () {
      final change = RateChange(
        changeId: 'test2',
        rateId: 'r1',
        bankId: 'sbi',
        previousRate: 7.80,
        newRate: 15.50,
        changedAt: DateTime.now(),
      );
      expect(change.absoluteChange, closeTo(7.70, 0.01));
      expect(change.isSuspicious, isTrue);
    });

    test('Moderate rate change is not suspicious', () {
      final change = RateChange(
        changeId: 'test3',
        rateId: 'r1',
        bankId: 'sbi',
        previousRate: 7.00,
        newRate: 7.50,
        changedAt: DateTime.now(),
      );
      expect(change.absoluteChange, closeTo(0.50, 0.01));
      expect(change.isSuspicious, isFalse);
    });
  });
}
