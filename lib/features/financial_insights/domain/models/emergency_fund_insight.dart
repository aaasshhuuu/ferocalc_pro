import 'dart:math' as math;
import 'financial_profile.dart';

/// Computed metrics for emergency fund readiness and reserve adequacy.
class EmergencyFundInsight {
  const EmergencyFundInsight({
    required this.currentSavings,
    required this.monthlyEssentialExpenses,
    required this.targetMonths,
    required this.coverageMonths,
    required this.targetAmount,
    required this.gap,
  });

  /// Liquid savings earmarked for emergencies.
  final double currentSavings;

  /// Monthly essential living cost baseline.
  final double monthlyEssentialExpenses;

  /// User-selected or default target duration in months.
  final int targetMonths;

  /// Coverage in months = Current Liquid Savings / Monthly Essential Expenses (0.0 if essential expenses == 0).
  final double coverageMonths;

  /// Target amount = Monthly Essential Expenses × Target Months.
  final double targetAmount;

  /// Shortfall = max(0, Target - Current Liquid Savings).
  final double gap;

  /// Whether current savings meets or surpasses the calculated target.
  bool get isTargetMet => currentSavings >= targetAmount && targetAmount > 0;

  /// True if essential expenses have not been declared (<= 0).
  bool get hasNoEssentialExpenses => monthlyEssentialExpenses <= 0;

  /// Percentage of target achieved (0 to 100%+).
  double get fundingPercent {
    if (targetAmount <= 0) {
      return currentSavings > 0 ? 100.0 : 0.0;
    }
    return ((currentSavings / targetAmount) * 100.0).clamp(0.0, 100.0);
  }

  /// Categorical readiness tier.
  EmergencyReadinessTier get readinessTier {
    if (hasNoEssentialExpenses) return EmergencyReadinessTier.unconfigured;
    if (coverageMonths >= targetMonths) return EmergencyReadinessTier.fullyFunded;
    if (coverageMonths >= 3.0) return EmergencyReadinessTier.moderate;
    if (coverageMonths > 0.0) return EmergencyReadinessTier.vulnerable;
    return EmergencyReadinessTier.none;
  }

  static EmergencyFundInsight fromProfile(
    FinancialProfile profile, {
    int? customTargetMonths,
  }) {
    final current = profile.emergencySavings;
    final essential = profile.essentialExpenses;
    final months = math.max(1, customTargetMonths ?? profile.emergencyTargetMonths);

    final double coverage;
    final double target;
    final double gap;

    if (essential <= 0) {
      coverage = 0.0;
      target = 0.0;
      gap = 0.0;
    } else {
      coverage = current / essential;
      target = essential * months;
      gap = math.max(0.0, target - current);
    }

    return EmergencyFundInsight(
      currentSavings: current,
      monthlyEssentialExpenses: essential,
      targetMonths: months,
      coverageMonths: coverage,
      targetAmount: target,
      gap: gap,
    );
  }
}

enum EmergencyReadinessTier {
  unconfigured('Needs Setup'),
  none('No Liquid Reserve'),
  vulnerable('Under-funded (<3 mos)'),
  moderate('Partial Cushion (3-5 mos)'),
  fullyFunded('Fully Funded');

  const EmergencyReadinessTier(this.label);
  final String label;
}
