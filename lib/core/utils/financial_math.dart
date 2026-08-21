import 'dart:math';

/// Comprehensive financial calculation engine for FinCalc Pro.
/// All formulas are mathematically verified for Indian financial standards.
class FinancialMath {
  // ═══════════════════════════════════════════════════════════════
  // LOAN CALCULATORS
  // ═══════════════════════════════════════════════════════════════

  /// Calculate EMI (Equated Monthly Installment)
  /// Formula: EMI = P × r × (1+r)^n / ((1+r)^n - 1)
  static double calculateEMI({
    required double principal,
    required double annualRate,
    required int months,
  }) {
    if (annualRate == 0) return principal / months;
    if (months == 0) return 0;
    final double r = annualRate / (12 * 100);
    final double factor = pow(1 + r, months).toDouble();
    return (principal * r * factor) / (factor - 1);
  }

  /// Reverse calculate maximum Loan Amount from EMI
  /// Formula: P = EMI × ((1+r)^n - 1) / (r × (1+r)^n)
  static double calculateLoanAmount({
    required double emi,
    required double annualRate,
    required int months,
  }) {
    if (annualRate == 0) return emi * months;
    final double r = annualRate / (12 * 100);
    final double factor = pow(1 + r, months).toDouble();
    return emi * (factor - 1) / (r * factor);
  }

  /// Calculate Interest Rate using Newton-Raphson iterative method
  /// Finds r such that: EMI = P × r × (1+r)^n / ((1+r)^n - 1)
  static double calculateInterestRate({
    required double principal,
    required double emi,
    required int months,
    int maxIterations = 1000,
    double tolerance = 1e-10,
  }) {
    if (principal <= 0 || emi <= 0 || months <= 0) return 0;

    // Initial guess
    double r = 0.01;

    for (int i = 0; i < maxIterations; i++) {
      final double factor = pow(1 + r, months).toDouble();
      final double f = principal * r * factor / (factor - 1) - emi;
      final double fPrime = principal *
          (factor * (factor - 1) - r * months * pow(1 + r, months - 1).toDouble() * (factor - 1) +
              r * factor * months * pow(1 + r, months - 1).toDouble()) /
          ((factor - 1) * (factor - 1));

      if (fPrime.abs() < 1e-20) break;
      final double rNew = r - f / fPrime;
      if ((rNew - r).abs() < tolerance) {
        return rNew * 12 * 100; // Convert to annual percentage
      }
      r = rNew;
      if (r < 0) r = 0.001;
    }
    return r * 12 * 100;
  }

  /// Calculate Loan Tenure in months
  /// Formula: n = -log(1 - P×r/EMI) / log(1+r)
  static int calculateLoanTenure({
    required double principal,
    required double annualRate,
    required double emi,
  }) {
    if (annualRate == 0) return (principal / emi).ceil();
    final double r = annualRate / (12 * 100);
    if (emi <= principal * r) return -1; // EMI too low, infinite tenure
    final double n = -log(1 - (principal * r / emi)) / log(1 + r);
    return n.ceil();
  }

  /// Generate complete amortization schedule
  static List<Map<String, double>> generateAmortizationSchedule({
    required double principal,
    required double annualRate,
    required int months,
  }) {
    final double emi = calculateEMI(
      principal: principal,
      annualRate: annualRate,
      months: months,
    );
    final double monthlyRate = annualRate / (12 * 100);

    final List<Map<String, double>> schedule = [];
    double balance = principal;

    for (int i = 1; i <= months; i++) {
      final double interest = balance * monthlyRate;
      final double principalPart = emi - interest;
      balance -= principalPart;
      if (balance < 0) balance = 0;

      schedule.add({
        'month': i.toDouble(),
        'emi': emi,
        'principal': principalPart,
        'interest': interest,
        'balance': balance,
      });
    }
    return schedule;
  }

  // ═══════════════════════════════════════════════════════════════
  // DEPOSIT CALCULATORS
  // ═══════════════════════════════════════════════════════════════

  /// Calculate FD Maturity Amount (Compound Interest)
  /// Formula: A = P × (1 + r/n)^(n×t)
  /// Supports combined tenure (years + months + days)
  static double calculateFDMaturity({
    required double principal,
    required double annualRate,
    required double years,
    int compoundingFrequency = 4, // Quarterly default for Indian banks
  }) {
    if (annualRate == 0) return principal;
    final double r = annualRate / 100;
    return principal *
        pow(1 + (r / compoundingFrequency), compoundingFrequency * years)
            .toDouble();
  }

  /// Calculate FD Interest
  static double calculateFDInterest({
    required double principal,
    required double annualRate,
    required double years,
    int compoundingFrequency = 4,
  }) {
    return calculateFDMaturity(
          principal: principal,
          annualRate: annualRate,
          years: years,
          compoundingFrequency: compoundingFrequency,
        ) -
        principal;
  }

  /// Convert combined tenure (Y + M + D) to fractional years
  static double combinedTenureToYears({
    int years = 0,
    int months = 0,
    int days = 0,
  }) {
    return years + (months / 12) + (days / 365);
  }

  /// Convert combined tenure to total days
  static int combinedTenureToDays({
    int years = 0,
    int months = 0,
    int days = 0,
  }) {
    return (years * 365) + (months * 30) + days;
  }

  /// Calculate RD Maturity (Indian bank quarterly compounding formula)
  /// Uses the standard RBI formula for RD
  static double calculateRDMaturity({
    required double monthlyDeposit,
    required double annualRate,
    required int months,
    int compoundingFrequency = 4, // Quarterly
  }) {
    final double r = annualRate / 100;
    final double n = compoundingFrequency.toDouble();
    double maturity = 0;

    for (int i = 0; i < months; i++) {
      final double remainingMonths = (months - i).toDouble();
      final double years = remainingMonths / 12;
      maturity += monthlyDeposit *
          pow(1 + (r / n), n * years).toDouble();
    }
    return maturity;
  }

  /// Calculate RD Interest
  static double calculateRDInterest({
    required double monthlyDeposit,
    required double annualRate,
    required int months,
  }) {
    final double maturity = calculateRDMaturity(
      monthlyDeposit: monthlyDeposit,
      annualRate: annualRate,
      months: months,
    );
    return maturity - (monthlyDeposit * months);
  }

  /// Calculate Savings Account growth with monthly contributions
  static double calculateSavings({
    required double initialAmount,
    required double monthlyContribution,
    required double annualRate,
    required int months,
  }) {
    final double r = annualRate / (12 * 100);
    double balance = initialAmount;
    for (int i = 0; i < months; i++) {
      balance = (balance + monthlyContribution) * (1 + r);
    }
    return balance;
  }

  // ═══════════════════════════════════════════════════════════════
  // INVESTMENT CALCULATORS
  // ═══════════════════════════════════════════════════════════════

  /// Calculate SIP (Systematic Investment Plan) Future Value
  /// Formula: FV = P × ((1+r)^n - 1) / r × (1+r)
  static double calculateSIPMaturity({
    required double monthlyInvestment,
    required double annualReturn,
    required int months,
  }) {
    if (annualReturn == 0) return monthlyInvestment * months;
    final double r = annualReturn / (12 * 100);
    final double factor = pow(1 + r, months).toDouble();
    return monthlyInvestment * ((factor - 1) / r) * (1 + r);
  }

  /// Calculate SWP (Systematic Withdrawal Plan)
  /// Returns final balance after periodic withdrawals
  static Map<String, double> calculateSWP({
    required double investment,
    required double withdrawal,
    required double annualReturn,
    required int months,
  }) {
    final double r = annualReturn / (12 * 100);
    double balance = investment;
    double totalWithdrawn = 0;
    int monthsLasted = 0;

    for (int i = 0; i < months; i++) {
      balance *= (1 + r);
      if (balance >= withdrawal) {
        balance -= withdrawal;
        totalWithdrawn += withdrawal;
        monthsLasted++;
      } else {
        totalWithdrawn += balance;
        balance = 0;
        monthsLasted++;
        break;
      }
    }

    return {
      'finalBalance': balance,
      'totalWithdrawn': totalWithdrawn,
      'totalEarnings': totalWithdrawn + balance - investment,
      'monthsLasted': monthsLasted.toDouble(),
    };
  }

  /// Calculate Lumpsum Investment Future Value
  /// Formula: FV = PV × (1 + r)^n
  static double calculateLumpsum({
    required double principal,
    required double annualReturn,
    required double years,
  }) {
    return principal * pow(1 + (annualReturn / 100), years).toDouble();
  }

  /// Calculate CAGR (Compound Annual Growth Rate)
  /// Formula: CAGR = (FV/PV)^(1/n) - 1
  static double calculateCAGR({
    required double initialValue,
    required double finalValue,
    required double years,
  }) {
    if (initialValue <= 0 || years <= 0) return 0;
    return (pow(finalValue / initialValue, 1 / years).toDouble() - 1) * 100;
  }

  // ═══════════════════════════════════════════════════════════════
  // GOVERNMENT SCHEMES
  // ═══════════════════════════════════════════════════════════════

  /// Calculate PPF (Public Provident Fund) Maturity
  /// Annual compounding, 15-year minimum lock-in
  static Map<String, double> calculatePPF({
    required double yearlyDeposit,
    required double annualRate,
    required int years,
  }) {
    final double r = annualRate / 100;
    double balance = 0;
    double totalDeposit = 0;

    for (int i = 0; i < years; i++) {
      balance = (balance + yearlyDeposit) * (1 + r);
      totalDeposit += yearlyDeposit;
    }

    return {
      'maturityValue': balance,
      'totalDeposit': totalDeposit,
      'totalInterest': balance - totalDeposit,
    };
  }

  /// Calculate EPF (Employee Provident Fund) Maturity
  /// Monthly contributions with annual interest credit (8.15%)
  static Map<String, double> calculateEPF({
    required double basicSalary,
    required double employeeContribution, // typically 12%
    required double employerContribution, // typically 3.67% to EPF (rest to EPS)
    required double annualRate, // 8.15%
    required double annualSalaryIncrease,
    required double currentBalance,
    required int currentAge,
    required int retirementAge,
  }) {
    final int yearsToRetirement = retirementAge - currentAge;
    double balance = currentBalance;
    double totalEmployeeContrib = 0;
    double totalEmployerContrib = 0;
    double salary = basicSalary;

    for (int year = 0; year < yearsToRetirement; year++) {
      final double monthlyEmployee = salary * (employeeContribution / 100);
      final double monthlyEmployer = salary * (employerContribution / 100);

      for (int month = 0; month < 12; month++) {
        balance += monthlyEmployee + monthlyEmployer;
        totalEmployeeContrib += monthlyEmployee;
        totalEmployerContrib += monthlyEmployer;
      }

      // Annual interest credit
      balance *= (1 + annualRate / 100);

      // Annual salary increase
      salary *= (1 + annualSalaryIncrease / 100);
    }

    return {
      'maturityValue': balance,
      'totalEmployeeContribution': totalEmployeeContrib,
      'totalEmployerContribution': totalEmployerContrib,
      'totalInterest': balance - totalEmployeeContrib - totalEmployerContrib - currentBalance,
    };
  }

  /// Calculate NPS (National Pension System) Maturity
  /// 60% lump sum tax-free, 40% annuity
  static Map<String, double> calculateNPS({
    required double monthlyInvestment,
    required double expectedReturn,
    required int currentAge,
    required int retirementAge,
  }) {
    final int years = retirementAge - currentAge;
    final int months = years * 12;
    final double maturity = calculateSIPMaturity(
      monthlyInvestment: monthlyInvestment,
      annualReturn: expectedReturn,
      months: months,
    );
    final double totalInvestment = monthlyInvestment * months;
    final double lumpSum = maturity * 0.60;
    final double annuityCorpus = maturity * 0.40;
    // Approximate monthly pension at 6% annuity rate
    final double monthlyPension = annuityCorpus * 0.06 / 12;

    return {
      'maturityValue': maturity,
      'totalInvestment': totalInvestment,
      'totalInterest': maturity - totalInvestment,
      'lumpSum': lumpSum,
      'annuityCorpus': annuityCorpus,
      'monthlyPension': monthlyPension,
    };
  }

  /// Calculate Sukanya Samriddhi Yojana (SSY)
  /// Supports both fixed and variable (step-up) yearly deposits
  /// Deposit period: 15 years, Maturity: when girl turns 21
  static Map<String, double> calculateSSY({
    required List<double> yearlyDeposits, // 15 values for variable, or 15 identical for fixed
    required double annualRate, // 8.2% current
    required int girlAge,
  }) {
    final int maturityYears = 21 - girlAge;
    final double r = annualRate / 100;
    double balance = 0;
    double totalDeposit = 0;

    for (int year = 0; year < maturityYears; year++) {
      // Deposits allowed only for first 15 years
      if (year < 15 && year < yearlyDeposits.length) {
        balance += yearlyDeposits[year];
        totalDeposit += yearlyDeposits[year];
      }
      // Interest compounded annually
      balance *= (1 + r);
    }

    return {
      'maturityValue': balance,
      'totalDeposit': totalDeposit,
      'totalInterest': balance - totalDeposit,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // TAX CALCULATORS
  // ═══════════════════════════════════════════════════════════════

  /// Calculate GST
  static Map<String, double> calculateGST({
    required double amount,
    required double gstRate,
    required bool isInclusive,
    required bool isInterState, // IGST vs CGST+SGST
  }) {
    double originalAmount;
    double gstAmount;

    if (isInclusive) {
      originalAmount = amount / (1 + gstRate / 100);
      gstAmount = amount - originalAmount;
    } else {
      originalAmount = amount;
      gstAmount = amount * gstRate / 100;
    }

    final double totalAmount = originalAmount + gstAmount;

    if (isInterState) {
      return {
        'originalAmount': originalAmount,
        'igst': gstAmount,
        'cgst': 0,
        'sgst': 0,
        'gstAmount': gstAmount,
        'totalAmount': totalAmount,
      };
    } else {
      return {
        'originalAmount': originalAmount,
        'igst': 0,
        'cgst': gstAmount / 2,
        'sgst': gstAmount / 2,
        'gstAmount': gstAmount,
        'totalAmount': totalAmount,
      };
    }
  }

  /// Calculate Income Tax — New Regime (FY 2024-25)
  static double calculateIncomeTaxNewRegime(double taxableIncome) {
    double tax = 0;
    final double income = taxableIncome - 75000; // Standard deduction

    if (income <= 0) return 0;

    if (income <= 300000) {
      tax = 0;
    } else if (income <= 700000) {
      tax = (income - 300000) * 0.05;
    } else if (income <= 1000000) {
      tax = 20000 + (income - 700000) * 0.10;
    } else if (income <= 1200000) {
      tax = 50000 + (income - 1000000) * 0.15;
    } else if (income <= 1500000) {
      tax = 80000 + (income - 1200000) * 0.20;
    } else {
      tax = 140000 + (income - 1500000) * 0.30;
    }

    // Section 87A rebate (income up to 7L)
    if (income <= 700000) tax = 0;

    // Health & Education Cess (4%)
    tax *= 1.04;

    return tax;
  }

  /// Calculate Income Tax — Old Regime (FY 2024-25)
  static double calculateIncomeTaxOldRegime({
    required double grossIncome,
    required int ageGroup, // 0: <60, 1: 60-80, 2: 80+
    double deduction80C = 0,
    double deduction80D = 0,
    double hra = 0,
    double standardDeduction = 50000,
    double otherDeductions = 0,
  }) {
    // Cap 80C at 1.5L
    deduction80C = deduction80C.clamp(0, 150000);

    final double totalDeductions =
        standardDeduction + deduction80C + deduction80D + hra + otherDeductions;
    double taxableIncome = grossIncome - totalDeductions;
    if (taxableIncome < 0) taxableIncome = 0;

    double tax = 0;
    double exemptionLimit;

    switch (ageGroup) {
      case 2: // Super Senior (80+)
        exemptionLimit = 500000;
        break;
      case 1: // Senior (60-80)
        exemptionLimit = 300000;
        break;
      default: // General (<60)
        exemptionLimit = 250000;
    }

    if (taxableIncome <= exemptionLimit) {
      tax = 0;
    } else if (taxableIncome <= 500000) {
      tax = (taxableIncome - exemptionLimit) * 0.05;
    } else if (taxableIncome <= 1000000) {
      tax = (500000 - exemptionLimit) * 0.05 + (taxableIncome - 500000) * 0.20;
    } else {
      tax = (500000 - exemptionLimit) * 0.05 +
          500000 * 0.20 +
          (taxableIncome - 1000000) * 0.30;
    }

    // Section 87A rebate
    if (taxableIncome <= 500000) tax = 0;

    // Health & Education Cess (4%)
    tax *= 1.04;

    return tax;
  }

  // ═══════════════════════════════════════════════════════════════
  // PLANNING CALCULATORS
  // ═══════════════════════════════════════════════════════════════

  /// Calculate future value adjusted for inflation
  static double calculateInflationAdjustedValue({
    required double presentValue,
    required double inflationRate,
    required double years,
  }) {
    return presentValue * pow(1 + (inflationRate / 100), years).toDouble();
  }

  /// Calculate retirement corpus needed
  static Map<String, double> calculateRetirementCorpus({
    required int currentAge,
    required int retirementAge,
    required double monthlyExpense,
    required double inflationRate,
    required double preRetirementReturn,
    required double postRetirementReturn,
    required int lifeExpectancy,
  }) {
    final int yearsToRetirement = retirementAge - currentAge;
    final int yearsInRetirement = lifeExpectancy - retirementAge;

    // Future monthly expense at retirement (inflation adjusted)
    final double futureMonthlyExpense = monthlyExpense *
        pow(1 + inflationRate / 100, yearsToRetirement).toDouble();
    final double futureAnnualExpense = futureMonthlyExpense * 12;

    // Corpus needed at retirement (PV of annuity)
    final double realReturnRate =
        ((1 + postRetirementReturn / 100) / (1 + inflationRate / 100)) - 1;
    double corpusNeeded;
    if (realReturnRate <= 0) {
      corpusNeeded = futureAnnualExpense * yearsInRetirement;
    } else {
      corpusNeeded = futureAnnualExpense *
          (1 - pow(1 + realReturnRate, -yearsInRetirement).toDouble()) /
          realReturnRate;
    }

    // Monthly SIP needed
    final double monthlyRate = preRetirementReturn / (12 * 100);
    final int months = yearsToRetirement * 12;
    double sipNeeded;
    if (monthlyRate == 0) {
      sipNeeded = corpusNeeded / months;
    } else {
      final double factor = pow(1 + monthlyRate, months).toDouble();
      sipNeeded = corpusNeeded * monthlyRate / ((factor - 1) * (1 + monthlyRate));
    }

    return {
      'corpusNeeded': corpusNeeded,
      'futureMonthlyExpense': futureMonthlyExpense,
      'monthlySIPNeeded': sipNeeded,
      'totalInvestmentNeeded': sipNeeded * months,
    };
  }

  /// Calculate Goal Planning
  static Map<String, double> calculateGoalPlanner({
    required double goalAmount,
    required int yearsToGoal,
    required double inflationRate,
    required double expectedReturn,
  }) {
    final double inflationAdjustedGoal =
        goalAmount * pow(1 + inflationRate / 100, yearsToGoal).toDouble();

    // Monthly SIP needed
    final double r = expectedReturn / (12 * 100);
    final int months = yearsToGoal * 12;
    double sipNeeded;
    if (r == 0) {
      sipNeeded = inflationAdjustedGoal / months;
    } else {
      final double factor = pow(1 + r, months).toDouble();
      sipNeeded = inflationAdjustedGoal * r / ((factor - 1) * (1 + r));
    }

    // Lumpsum needed
    final double lumpsumNeeded =
        inflationAdjustedGoal / pow(1 + expectedReturn / 100, yearsToGoal).toDouble();

    return {
      'inflationAdjustedGoal': inflationAdjustedGoal,
      'monthlySIPNeeded': sipNeeded,
      'lumpsumNeeded': lumpsumNeeded,
    };
  }

  /// Calculate Education Planning
  static Map<String, double> calculateEducationPlanner({
    required int childAge,
    required int educationStartAge,
    required double currentCost,
    required double educationInflation,
    required double expectedReturn,
  }) {
    final int yearsToEducation = educationStartAge - childAge;
    return calculateGoalPlanner(
      goalAmount: currentCost,
      yearsToGoal: yearsToEducation,
      inflationRate: educationInflation,
      expectedReturn: expectedReturn,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ELIGIBILITY CALCULATORS
  // ═══════════════════════════════════════════════════════════════

  /// Calculate Home Loan Eligibility based on FOIR
  static Map<String, double> calculateHomeLoanEligibility({
    required double monthlyIncome,
    required double monthlyExpenses,
    required double annualRate,
    required int tenureMonths,
    required double existingEMIs,
    required double foir, // 40-65% typically
  }) {
    final double eligibleEMI =
        (monthlyIncome * foir / 100) - existingEMIs;
    if (eligibleEMI <= 0) {
      return {
        'maxLoanAmount': 0,
        'eligibleEMI': 0,
        'totalInterest': 0,
        'totalPayment': 0,
      };
    }

    final double maxLoan = calculateLoanAmount(
      emi: eligibleEMI,
      annualRate: annualRate,
      months: tenureMonths,
    );

    final double totalPayment = eligibleEMI * tenureMonths;

    return {
      'maxLoanAmount': maxLoan,
      'eligibleEMI': eligibleEMI,
      'totalInterest': totalPayment - maxLoan,
      'totalPayment': totalPayment,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // STOCK/EQUITY CALCULATORS
  // ═══════════════════════════════════════════════════════════════

  /// Calculate Stock Returns with dividends and charges
  static Map<String, double> calculateStockReturn({
    required double buyPrice,
    required double sellPrice,
    required int quantity,
    required double holdingYears,
    required double annualDividendPerShare,
    required double brokeragePercent,
  }) {
    final double totalInvestment = buyPrice * quantity;
    final double totalSellValue = sellPrice * quantity;
    final double capitalGain = totalSellValue - totalInvestment;
    final double dividendIncome = annualDividendPerShare * quantity * holdingYears;
    final double brokerageCost = (totalInvestment + totalSellValue) * brokeragePercent / 100;
    final double netProfit = capitalGain + dividendIncome - brokerageCost;

    // CAGR
    final double totalReturn = totalInvestment + netProfit;
    final double cagr = calculateCAGR(
      initialValue: totalInvestment,
      finalValue: totalReturn,
      years: holdingYears,
    );

    // Tax: STCG (15%) if < 1 year, LTCG (10% above ₹1L) if >= 1 year
    double tax;
    if (holdingYears < 1) {
      tax = capitalGain > 0 ? capitalGain * 0.15 : 0;
    } else {
      final double taxableGain = capitalGain > 100000 ? capitalGain - 100000 : 0;
      tax = taxableGain * 0.10;
    }

    return {
      'totalInvestment': totalInvestment,
      'capitalGain': capitalGain,
      'dividendIncome': dividendIncome,
      'brokerageCost': brokerageCost,
      'netProfit': netProfit,
      'cagr': cagr,
      'tax': tax,
      'netProfitAfterTax': netProfit - tax,
    };
  }

  /// Calculate Dividend Yield
  static Map<String, double> calculateDividendYield({
    required double sharePrice,
    required double annualDividend,
    required int numberOfShares,
    required double dividendGrowthRate,
    required int years,
  }) {
    final double currentYield = (annualDividend / sharePrice) * 100;
    double totalDividend = 0;
    double currentDividend = annualDividend * numberOfShares;

    for (int i = 0; i < years; i++) {
      totalDividend += currentDividend;
      currentDividend *= (1 + dividendGrowthRate / 100);
    }

    final double futureAnnualDividend =
        annualDividend * pow(1 + dividendGrowthRate / 100, years).toDouble();
    final double yieldOnCost = (futureAnnualDividend / sharePrice) * 100;

    return {
      'currentYield': currentYield,
      'annualIncome': annualDividend * numberOfShares,
      'totalDividend': totalDividend,
      'yieldOnCost': yieldOnCost,
      'futureAnnualDividend': futureAnnualDividend * numberOfShares,
    };
  }

  /// Calculate Credit Card EMI with processing fee
  static Map<String, double> calculateCreditCardEMI({
    required double outstanding,
    required double annualRate,
    required int months,
    required double processingFeePercent,
  }) {
    final double processingFee = outstanding * processingFeePercent / 100;
    final double emi = calculateEMI(
      principal: outstanding,
      annualRate: annualRate,
      months: months,
    );
    final double totalPayment = emi * months;

    return {
      'emi': emi,
      'processingFee': processingFee,
      'totalInterest': totalPayment - outstanding,
      'totalPayment': totalPayment + processingFee,
    };
  }
}
