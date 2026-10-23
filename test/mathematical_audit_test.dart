import 'package:flutter_test/flutter_test.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

void main() {
  group('1. EMI / Loan Calculators Mathematical Audit', () {
    test('Standard EMI golden numerical verification', () {
      // P = 10,00,000, r = 8.5% p.a., n = 120 months
      // Hand-derived golden: 12,398.57
      final emi = FinancialMath.calculateEMI(
        principal: 1000000,
        annualRate: 8.5,
        months: 120,
      );
      expect(emi, closeTo(12398.57, 0.01));
    });

    test('Zero interest rate returns exact simple division', () {
      final emi = FinancialMath.calculateEMI(
        principal: 1200000,
        annualRate: 0,
        months: 12,
      );
      expect(emi, equals(100000.0));
    });

    test('Reverse calculate Loan Amount from EMI', () {
      // EMI = 12,398.568887..., r = 8.5%, n = 120 -> P = 10,00,000
      final p = FinancialMath.calculateLoanAmount(
        emi: 12398.568887451112,
        annualRate: 8.5,
        months: 120,
      );
      expect(p, closeTo(1000000.0, 0.01));
    });

    test('Reverse calculate Interest Rate with Newton-Raphson quadratic convergence', () {
      // P = 10,00,000, EMI = 12,398.568887..., n = 120 -> r = 8.50%
      final rate = FinancialMath.calculateInterestRate(
        principal: 1000000,
        emi: 12398.568887451112,
        months: 120,
      );
      expect(rate, closeTo(8.5, 0.0001));
    });

    test('Interest rate boundary: emi * months <= principal returns 0', () {
      final zeroRate = FinancialMath.calculateInterestRate(
        principal: 1000000,
        emi: 1000000 / 120,
        months: 120,
      );
      expect(zeroRate, equals(0.0));

      final impossibleRate = FinancialMath.calculateInterestRate(
        principal: 1000000,
        emi: 5000,
        months: 120,
      );
      expect(impossibleRate, equals(0.0));
    });

    test('Reverse calculate Loan Tenure from EMI', () {
      final tenure = FinancialMath.calculateLoanTenure(
        principal: 1000000,
        annualRate: 8.5,
        emi: 12398.568887451112,
      );
      expect(tenure, equals(120));
    });

    test('Loan Tenure returns -1 when EMI <= principal * monthly rate', () {
      // r_monthly = 8.5 / 1200 = 0.00708333... * 10,00,000 = 7,083.33 minimum interest
      final tenure = FinancialMath.calculateLoanTenure(
        principal: 1000000,
        annualRate: 8.5,
        emi: 5000,
      );
      expect(tenure, equals(-1));
    });

    test('Credit Card EMI calculation with processing fee reconciliation', () {
      final result = FinancialMath.calculateCreditCardEMI(
        outstanding: 50000,
        annualRate: 18.0,
        months: 12,
        processingFeePercent: 2.0,
      );
      expect(result['emi']!, closeTo(4584.00, 0.01));
      expect(result['processingFee']!, equals(1000.0));
      expect(result['totalInterest']!, closeTo(5008.00, 0.01));
      expect(result['totalPayment']!, closeTo(56008.00, 0.01));
      // Cross-reconciliation
      expect(result['totalPayment']!, closeTo(50000 + result['totalInterest']! + result['processingFee']!, 0.01));
    });

    test('Amortization schedule reconciliation and zero terminal balance', () {
      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: 1000000,
        annualRate: 10.0,
        months: 12,
      );
      expect(schedule.length, equals(12));
      double totalPrincipalRepaid = 0;
      double totalInterestPaid = 0;
      for (final row in schedule) {
        totalPrincipalRepaid += row['principal']!;
        totalInterestPaid += row['interest']!;
      }
      expect(totalPrincipalRepaid, closeTo(1000000.0, 0.01));
      expect(schedule.last['balance']!, closeTo(0.0, 0.01));
      final emi = schedule.first['emi']!;
      expect(totalPrincipalRepaid + totalInterestPaid, closeTo(emi * 12, 0.01));
    });

    test('Home Loan Eligibility based on FOIR', () {
      final result = FinancialMath.calculateHomeLoanEligibility(
        monthlyIncome: 100000,
        monthlyExpenses: 0,
        annualRate: 8.5,
        tenureMonths: 240,
        existingEMIs: 10000,
        foir: 50.0,
      );
      expect(result['eligibleEMI']!, equals(40000.0));
      expect(result['maxLoanAmount']!, closeTo(4609233.59, 0.01));
      expect(result['totalPayment']!, equals(9600000.0));
      expect(result['totalInterest']!, closeTo(4990766.41, 0.01));
    });
  });

  group('2. Deposit Calculators Mathematical Audit', () {
    test('FD maturity with quarterly compounding', () {
      final maturity = FinancialMath.calculateFDMaturity(
        principal: 100000,
        annualRate: 7.0,
        years: 1,
        compoundingFrequency: 4,
      );
      expect(maturity, closeTo(107185.90, 0.01));
      final interest = FinancialMath.calculateFDInterest(
        principal: 100000,
        annualRate: 7.0,
        years: 1,
        compoundingFrequency: 4,
      );
      expect(interest, closeTo(7185.90, 0.01));
    });

    test('FD edge cases: zero interest, zero principal, zero years', () {
      expect(FinancialMath.calculateFDMaturity(principal: 100000, annualRate: 0, years: 5), equals(100000.0));
      expect(FinancialMath.calculateFDMaturity(principal: 0, annualRate: 7.0, years: 5), equals(0.0));
      expect(FinancialMath.calculateFDMaturity(principal: 100000, annualRate: 7.0, years: 0), equals(100000.0));
    });

    test('RD maturity with standard quarterly compounding formula', () {
      // 5,000 monthly, 6.5% p.a., 12 months
      final maturity = FinancialMath.calculateRDMaturity(
        monthlyDeposit: 5000,
        annualRate: 6.5,
        months: 12,
        compoundingFrequency: 4,
      );
      expect(maturity, closeTo(62143.23, 0.05));
      final interest = FinancialMath.calculateRDInterest(
        monthlyDeposit: 5000,
        annualRate: 6.5,
        months: 12,
      );
      expect(interest, closeTo(2143.23, 0.05));
      expect(5000 * 12 + interest, closeTo(maturity, 0.01));
    });

    test('RD edge cases: zero deposit, zero months, zero rate', () {
      expect(FinancialMath.calculateRDMaturity(monthlyDeposit: 0, annualRate: 6.5, months: 12), equals(0.0));
      expect(FinancialMath.calculateRDMaturity(monthlyDeposit: 5000, annualRate: 6.5, months: 0), equals(0.0));
      expect(FinancialMath.calculateRDMaturity(monthlyDeposit: 5000, annualRate: 0, months: 12), equals(60000.0));
    });

    test('Savings account with monthly contributions', () {
      final balance = FinancialMath.calculateSavings(
        initialAmount: 10000,
        monthlyContribution: 2000,
        annualRate: 4.0,
        months: 12,
      );
      expect(balance, closeTo(34933.82, 0.01));
    });

    test('PPF 15-year maturity calculation', () {
      final result = FinancialMath.calculatePPF(
        yearlyDeposit: 150000,
        annualRate: 7.1,
        years: 15,
      );
      expect(result['totalDeposit']!, equals(2250000.0));
      expect(result['maturityValue']!, closeTo(4068209.22, 0.01));
      expect(result['totalInterest']!, closeTo(1818209.22, 0.01));
      expect(result['totalDeposit']! + result['totalInterest']!, equals(result['maturityValue']!));
    });
  });

  group('3. Investment Calculators Mathematical Audit', () {
    test('SIP Future Value (Annuity Due)', () {
      // 10,000 monthly, 12% p.a., 120 months
      final fv = FinancialMath.calculateSIPMaturity(
        monthlyInvestment: 10000,
        annualReturn: 12.0,
        months: 120,
      );
      expect(fv, closeTo(2323390.76, 0.01));
    });

    test('SIP zero return returns simple sum', () {
      final fv = FinancialMath.calculateSIPMaturity(
        monthlyInvestment: 10000,
        annualReturn: 0,
        months: 12,
      );
      expect(fv, equals(120000.0));
    });

    test('SWP systematic withdrawal plan reconciliation', () {
      final result = FinancialMath.calculateSWP(
        investment: 1000000,
        withdrawal: 10000,
        annualReturn: 8.0,
        months: 120,
      );
      expect(result['finalBalance']!, closeTo(390179.88, 0.01));
      expect(result['totalWithdrawn']!, equals(1200000.0));
      expect(result['totalEarnings']!, closeTo(590179.88, 0.01));
      expect(result['totalWithdrawn']! + result['finalBalance']!, closeTo(1000000 + result['totalEarnings']!, 0.01));
    });

    test('SWP depletion before full tenure', () {
      final result = FinancialMath.calculateSWP(
        investment: 100000,
        withdrawal: 20000,
        annualReturn: 6.0,
        months: 12,
      );
      expect(result['finalBalance']!, equals(0.0));
      expect(result['monthsLasted']!, lessThan(12.0));
    });

    test('Lumpsum investment growth', () {
      final fv = FinancialMath.calculateLumpsum(
        principal: 100000,
        annualReturn: 12.0,
        years: 10,
      );
      expect(fv, closeTo(310584.82, 0.01));
    });

    test('CAGR calculation and negative return handling', () {
      final cagr = FinancialMath.calculateCAGR(
        initialValue: 10000,
        finalValue: 20000,
        years: 5,
      );
      expect(cagr, closeTo(14.87, 0.01));

      final cagrLoss = FinancialMath.calculateCAGR(
        initialValue: 20000,
        finalValue: 10000,
        years: 5,
      );
      expect(cagrLoss, closeTo(-12.94, 0.01));

      // Guarded negative finalValue does not return NaN
      final cagrNegative = FinancialMath.calculateCAGR(
        initialValue: 10000,
        finalValue: -500,
        years: 5,
      );
      expect(cagrNegative, equals(-100.0));
    });

    test('Stock Return calculation with capital gain, dividend, brokerage and taxes', () {
      final result = FinancialMath.calculateStockReturn(
        buyPrice: 100,
        sellPrice: 150,
        quantity: 100,
        holdingYears: 2,
        annualDividendPerShare: 5,
        brokeragePercent: 0.5,
      );
      expect(result['totalInvestment']!, equals(10000.0));
      expect(result['capitalGain']!, equals(5000.0));
      expect(result['dividendIncome']!, equals(1000.0));
      expect(result['brokerageCost']!, equals(125.0));
      expect(result['netProfit']!, equals(5875.0));
      expect(result['cagr']!, closeTo(26.00, 0.01));
      expect(result['tax']!, equals(0.0)); // LTCG <= 1L exemption
      expect(result['netProfitAfterTax']!, equals(5875.0));
    });

    test('Dividend Yield calculation and zero share price guard', () {
      final result = FinancialMath.calculateDividendYield(
        sharePrice: 200,
        annualDividend: 10,
        numberOfShares: 100,
        dividendGrowthRate: 5.0,
        years: 5,
      );
      expect(result['currentYield']!, equals(5.0));
      expect(result['annualIncome']!, equals(1000.0));
      expect(result['totalDividend']!, closeTo(5525.63, 0.01));
      expect(result['yieldOnCost']!, closeTo(6.38, 0.01));

      // Zero share price does not return Infinity
      final zeroPrice = FinancialMath.calculateDividendYield(
        sharePrice: 0,
        annualDividend: 10,
        numberOfShares: 100,
        dividendGrowthRate: 5.0,
        years: 5,
      );
      expect(zeroPrice['currentYield']!, equals(0.0));
    });

    test('NPS accumulation, lump sum and annuity breakdown', () {
      final result = FinancialMath.calculateNPS(
        monthlyInvestment: 5000,
        expectedReturn: 10.0,
        currentAge: 30,
        retirementAge: 60,
      );
      expect(result['totalInvestment']!, equals(1800000.0));
      expect(result['maturityValue']!, closeTo(11396626.62, 0.01));
      expect(result['lumpSum']!, closeTo(6837975.97, 0.01));
      expect(result['annuityCorpus']!, closeTo(4558650.65, 0.01));
      expect(result['monthlyPension']!, closeTo(22793.25, 0.01));
      expect(result['lumpSum']! + result['annuityCorpus']!, equals(result['maturityValue']!));
    });

    test('EPF calculation reconciliation', () {
      final result = FinancialMath.calculateEPF(
        basicSalary: 30000,
        employeeContribution: 12.0,
        employerContribution: 3.67,
        annualRate: 8.15,
        annualSalaryIncrease: 5.0,
        currentBalance: 50000,
        currentAge: 25,
        retirementAge: 58,
      );
      expect(result['maturityValue']!, closeTo(16675024.42, 0.01));
      expect(result['totalEmployeeContribution']!, closeTo(3458754.90, 0.01));
      expect(result['totalEmployerContribution']!, closeTo(1057802.54, 0.01));
      expect(result['totalInterest']!, closeTo(12108466.98, 0.01));
    });

    test('Sukanya Samriddhi Yojana (SSY) 15-year deposit calculation', () {
      final result = FinancialMath.calculateSSY(
        yearlyDeposits: List.filled(15, 100000),
        annualRate: 8.2,
        girlAge: 1,
      );
      expect(result['totalDeposit']!, equals(1500000.0));
      expect(result['maturityValue']!, closeTo(4425212.06, 0.01));
      expect(result['totalInterest']!, closeTo(2925212.06, 0.01));
      expect(result['totalDeposit']! + result['totalInterest']!, equals(result['maturityValue']!));
    });
  });

  group('4. Tax & GST Calculators Mathematical Audit', () {
    test('GST Exclusive calculation', () {
      final result = FinancialMath.calculateGST(
        amount: 1000,
        gstRate: 18.0,
        isInclusive: false,
        isInterState: false,
      );
      expect(result['originalAmount']!, equals(1000.0));
      expect(result['gstAmount']!, equals(180.0));
      expect(result['totalAmount']!, equals(1180.0));
      expect(result['cgst']!, equals(90.0));
      expect(result['sgst']!, equals(90.0));
      expect(result['igst']!, equals(0.0));
    });

    test('GST Inclusive calculation', () {
      final result = FinancialMath.calculateGST(
        amount: 1180,
        gstRate: 18.0,
        isInclusive: true,
        isInterState: true,
      );
      expect(result['originalAmount']!, equals(1000.0));
      expect(result['gstAmount']!, equals(180.0));
      expect(result['totalAmount']!, equals(1180.0));
      expect(result['igst']!, equals(180.0));
      expect(result['cgst']!, equals(0.0));
    });

    test('Income Tax New Regime FY 2024-25 slabs with 75k standard deduction', () {
      // 7.5L gross - 75k SD = 6.75L taxable <= 7L -> 0 tax (87A rebate)
      expect(FinancialMath.calculateIncomeTaxNewRegime(750000), equals(0.0));

      // 10L gross - 75k SD = 9.25L taxable:
      // 3L-7L (4L @ 5%) = 20k
      // 7L-9.25L (2.25L @ 10%) = 22.5k
      // Base = 42.5k * 1.04 cess = 44,200
      expect(FinancialMath.calculateIncomeTaxNewRegime(1000000), equals(44200.0));
    });

    test('Income Tax Old Regime slabs with age groups and 87A rebate', () {
      // General (<60): 5L gross - 50k SD = 4.5L taxable <= 5L -> 0 tax (87A rebate)
      expect(FinancialMath.calculateIncomeTaxOldRegime(grossIncome: 500000, ageGroup: 0), equals(0.0));

      // General (<60): 10L gross - 50k SD - 1.5L 80C - 25k 80D = 7.75L taxable:
      // 2.5L-5L (2.5L @ 5%) = 12.5k
      // 5L-7.75L (2.75L @ 20%) = 55k
      // Base = 67.5k * 1.04 cess = 70,200
      final tax = FinancialMath.calculateIncomeTaxOldRegime(
        grossIncome: 1000000,
        ageGroup: 0,
        deduction80C: 150000,
        deduction80D: 25000,
        standardDeduction: 50000,
      );
      expect(tax, equals(70200.0));

      // Super Senior (80+): exemption limit is 5L
      final superSeniorTax = FinancialMath.calculateIncomeTaxOldRegime(
        grossIncome: 600000,
        ageGroup: 2,
        standardDeduction: 50000,
      );
      // Taxable = 5.5L: 5L-5.5L (50k @ 20%) = 10k * 1.04 = 10,400
      expect(superSeniorTax, equals(10400.0));
    });
  });

  group('5. Planning Calculators Mathematical Audit', () {
    test('Inflation adjusted future value', () {
      final future = FinancialMath.calculateInflationAdjustedValue(
        presentValue: 100000,
        inflationRate: 6.0,
        years: 10,
      );
      expect(future, closeTo(179084.77, 0.01));
    });

    test('Retirement Corpus and monthly SIP requirement', () {
      final result = FinancialMath.calculateRetirementCorpus(
        currentAge: 30,
        retirementAge: 60,
        monthlyExpense: 40000,
        inflationRate: 6.0,
        preRetirementReturn: 12.0,
        postRetirementReturn: 8.0,
        lifeExpectancy: 80,
      );
      expect(result['futureMonthlyExpense']!, closeTo(229739.65, 0.01));
      expect(result['corpusNeeded']!, closeTo(45575253.57, 0.01));
      expect(result['monthlySIPNeeded']!, closeTo(12911.15, 0.01));
    });

    test('Goal Planner future value, SIP, and lumpsum cross-consistency', () {
      final result = FinancialMath.calculateGoalPlanner(
        goalAmount: 2000000,
        yearsToGoal: 10,
        inflationRate: 6.0,
        expectedReturn: 12.0,
      );
      final target = result['inflationAdjustedGoal']!;
      expect(target, closeTo(3581695.39, 0.01));
      final sipNeeded = result['monthlySIPNeeded']!;
      expect(sipNeeded, closeTo(15415.81, 0.01));
      final lumpsumNeeded = result['lumpsumNeeded']!;
      expect(lumpsumNeeded, closeTo(1153210.06, 0.01));

      // Cross-verification: Investing sipNeeded in SIP for 10 years at 12% must yield target
      final sipMaturity = FinancialMath.calculateSIPMaturity(
        monthlyInvestment: sipNeeded,
        annualReturn: 12.0,
        months: 120,
      );
      expect(sipMaturity, closeTo(target, 0.01));

      // Cross-verification: Investing lumpsumNeeded in Lumpsum for 10 years at 12% must yield target
      final lumpsumMaturity = FinancialMath.calculateLumpsum(
        principal: lumpsumNeeded,
        annualReturn: 12.0,
        years: 10,
      );
      expect(lumpsumMaturity, closeTo(target, 0.01));
    });

    test('Education Planner delegates correctly to goal planner', () {
      final result = FinancialMath.calculateEducationPlanner(
        childAge: 5,
        educationStartAge: 18,
        currentCost: 1500000,
        educationInflation: 8.0,
        expectedReturn: 12.0,
      );
      expect(result['inflationAdjustedGoal']!, closeTo(4079435.59, 0.01));
      expect(result['monthlySIPNeeded']!, closeTo(10851.55, 0.01));
      expect(result['lumpsumNeeded']!, closeTo(934901.35, 0.01));
    });
  });
}
