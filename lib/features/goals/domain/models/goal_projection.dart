import 'dart:math' as math;

/// Deterministic projection result computed by the financial goal engine.
class GoalProjection {
  const GoalProjection({
    required this.targetAmount,
    required this.currentSavings,
    required this.targetMonths,
    required this.isInflationEnabled,
    required this.inflationRate,
    required this.expectedReturn,
    required this.inflationAdjustedTarget,
    required this.futureSavingsValue,
    required this.remainingGap,
    required this.monthlyContribution,
    required this.totalContributions,
    required this.totalInvested,
    required this.totalProjectedValue,
    required this.projectedGrowth,
    required this.progressPercent,
  });

  final double targetAmount;
  final double currentSavings;
  final int targetMonths;
  final bool isInflationEnabled;
  final double inflationRate;
  final double expectedReturn;
  final double inflationAdjustedTarget;
  final double futureSavingsValue;
  final double remainingGap;
  final double monthlyContribution;
  final double totalContributions;
  final double totalInvested;
  final double totalProjectedValue;
  final double projectedGrowth;
  final double progressPercent;

  /// Centralized deterministic calculation engine following exact Phase 5.0.5 requirements:
  ///
  /// - End-of-month contributions with effective annual return R:
  ///   monthlyRate = (1 + R)^(1/12) - 1
  /// - For positive monthly rate:
  ///   monthlyContribution = remainingTarget * monthlyRate / ((1 + monthlyRate)^months - 1)
  /// - For zero return:
  ///   monthlyContribution = remainingTarget / months
  /// - Current savings projected independently:
  ///   futureSavingsValue = currentSavings * (1 + R)^(months / 12)
  /// - Inflation-adjusted target:
  ///   inflationAdjustedTarget = targetAmount * (1 + inflationRate)^(months / 12)
  static GoalProjection calculate({
    required double targetAmount,
    required double currentSavings,
    required int targetMonths,
    bool isInflationEnabled = true,
    double inflationRate = 6.0,
    double expectedReturn = 12.0,
  }) {
    final sanitizedTarget = math.max(0.0, targetAmount);
    final sanitizedSavings = math.max(0.0, currentSavings);
    final sanitizedMonths = math.max(1, targetMonths);
    final sanitizedInflation = math.max(0.0, inflationRate);
    final sanitizedReturn = math.max(0.0, expectedReturn);

    final years = sanitizedMonths / 12.0;

    // 1. Inflation adjustment
    final double inflationAdjustedTarget;
    if (isInflationEnabled && sanitizedInflation > 0) {
      inflationAdjustedTarget = sanitizedTarget *
          math.pow(1.0 + sanitizedInflation / 100.0, years).toDouble();
    } else {
      inflationAdjustedTarget = sanitizedTarget;
    }

    // 2. Future value of current savings
    final double futureSavingsValue;
    if (sanitizedSavings > 0) {
      if (sanitizedReturn > 0) {
        futureSavingsValue = sanitizedSavings *
            math.pow(1.0 + sanitizedReturn / 100.0, years).toDouble();
      } else {
        futureSavingsValue = sanitizedSavings;
      }
    } else {
      futureSavingsValue = 0.0;
    }

    // 3. Remaining target gap
    final remainingGap =
        math.max(0.0, inflationAdjustedTarget - futureSavingsValue);

    // 4. Required monthly contribution
    final double monthlyContribution;
    if (remainingGap <= 0) {
      monthlyContribution = 0.0;
    } else if (sanitizedReturn <= 0) {
      monthlyContribution = remainingGap / sanitizedMonths;
    } else {
      final monthlyRate =
          math.pow(1.0 + sanitizedReturn / 100.0, 1.0 / 12.0).toDouble() - 1.0;
      final compoundFactor =
          math.pow(1.0 + monthlyRate, sanitizedMonths).toDouble();
      if (compoundFactor <= 1.0) {
        monthlyContribution = remainingGap / sanitizedMonths;
      } else {
        monthlyContribution =
            remainingGap * monthlyRate / (compoundFactor - 1.0);
      }
    }

    final totalContributions = monthlyContribution * sanitizedMonths;
    final totalInvested = sanitizedSavings + totalContributions;
    final totalProjectedValue = (remainingGap <= 0)
        ? futureSavingsValue
        : (futureSavingsValue + remainingGap);
    final projectedGrowth =
        math.max(0.0, totalProjectedValue - totalInvested);
    final progressPercent = (sanitizedTarget > 0)
        ? ((sanitizedSavings / sanitizedTarget) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    return GoalProjection(
      targetAmount: sanitizedTarget,
      currentSavings: sanitizedSavings,
      targetMonths: sanitizedMonths,
      isInflationEnabled: isInflationEnabled,
      inflationRate: sanitizedInflation,
      expectedReturn: sanitizedReturn,
      inflationAdjustedTarget: inflationAdjustedTarget,
      futureSavingsValue: futureSavingsValue,
      remainingGap: remainingGap,
      monthlyContribution: monthlyContribution,
      totalContributions: totalContributions,
      totalInvested: totalInvested,
      totalProjectedValue: totalProjectedValue,
      projectedGrowth: projectedGrowth,
      progressPercent: progressPercent,
    );
  }

  /// Calculates scenario outcome if the user adjusts monthly contribution, expected return, or duration.
  static GoalScenarioResult simulateScenario({
    required double targetAmount,
    required double currentSavings,
    required int months,
    required bool isInflationEnabled,
    required double inflationRate,
    required double expectedReturn,
    required double actualMonthlyContribution,
  }) {
    final sanitizedTarget = math.max(0.0, targetAmount);
    final sanitizedSavings = math.max(0.0, currentSavings);
    final sanitizedMonths = math.max(1, months);
    final sanitizedInflation = math.max(0.0, inflationRate);
    final sanitizedReturn = math.max(0.0, expectedReturn);
    final sanitizedContribution = math.max(0.0, actualMonthlyContribution);

    final years = sanitizedMonths / 12.0;

    // Target cost
    final double targetCost = (isInflationEnabled && sanitizedInflation > 0)
        ? sanitizedTarget *
            math.pow(1.0 + sanitizedInflation / 100.0, years).toDouble()
        : sanitizedTarget;

    // Savings future value
    final double futureSavings = (sanitizedSavings > 0)
        ? (sanitizedReturn > 0
            ? sanitizedSavings *
                math.pow(1.0 + sanitizedReturn / 100.0, years).toDouble()
            : sanitizedSavings)
        : 0.0;

    // Future value of contributions
    final double futureContributions;
    if (sanitizedContribution <= 0) {
      futureContributions = 0.0;
    } else if (sanitizedReturn <= 0) {
      futureContributions = sanitizedContribution * sanitizedMonths;
    } else {
      final monthlyRate =
          math.pow(1.0 + sanitizedReturn / 100.0, 1.0 / 12.0).toDouble() - 1.0;
      final compoundFactor =
          math.pow(1.0 + monthlyRate, sanitizedMonths).toDouble();
      futureContributions =
          sanitizedContribution * (compoundFactor - 1.0) / monthlyRate;
    }

    final totalAccumulated = futureSavings + futureContributions;
    final surplus = math.max(0.0, totalAccumulated - targetCost);
    final shortfall = math.max(0.0, targetCost - totalAccumulated);
    final isAchieved = totalAccumulated >= targetCost;

    return GoalScenarioResult(
      monthlyContribution: sanitizedContribution,
      expectedReturn: sanitizedReturn,
      months: sanitizedMonths,
      targetCost: targetCost,
      totalAccumulated: totalAccumulated,
      surplus: surplus,
      shortfall: shortfall,
      isAchieved: isAchieved,
    );
  }
}

class GoalScenarioResult {
  const GoalScenarioResult({
    required this.monthlyContribution,
    required this.expectedReturn,
    required this.months,
    required this.targetCost,
    required this.totalAccumulated,
    required this.surplus,
    required this.shortfall,
    required this.isAchieved,
  });

  final double monthlyContribution;
  final double expectedReturn;
  final int months;
  final double targetCost;
  final double totalAccumulated;
  final double surplus;
  final double shortfall;
  final bool isAchieved;
}
