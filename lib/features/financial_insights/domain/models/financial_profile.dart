import 'dart:math' as math;

/// Local-first personal financial profile stored strictly on-device.
/// Never uploaded to Supabase or public APIs.
class FinancialProfile {
  const FinancialProfile({
    this.monthlyIncome = 0.0,
    this.essentialExpenses = 0.0,
    this.discretionaryExpenses = 0.0,
    this.monthlyEmi = 0.0,
    this.declaredSavings = 0.0,
    this.emergencySavings = 0.0,
    this.emergencyTargetMonths = 6,
    this.updatedAt,
  });

  /// Monthly take-home (net) income in INR.
  final double monthlyIncome;

  /// Monthly essential expenses (housing, utilities, groceries, basic healthcare, insurance).
  final double essentialExpenses;

  /// Monthly discretionary expenses (dining out, entertainment, shopping, leisure).
  final double discretionaryExpenses;

  /// Monthly committed debt/EMI obligations (home, car, personal, credit card EMIs).
  final double monthlyEmi;

  /// Declared monthly savings and investment contributions (SIPs, PPF, RD, NPS, gold).
  final double declaredSavings;

  /// Current liquid emergency savings (savings accounts, liquid mutual funds, short deposits).
  final double emergencySavings;

  /// Target emergency fund coverage in months (default: 6 months).
  final int emergencyTargetMonths;

  /// Timestamp of last user modification.
  final DateTime? updatedAt;

  /// True if the user has entered any non-zero cash flow or emergency fund parameter.
  bool get isConfigured =>
      monthlyIncome > 0 ||
      essentialExpenses > 0 ||
      discretionaryExpenses > 0 ||
      monthlyEmi > 0 ||
      declaredSavings > 0 ||
      emergencySavings > 0;

  /// Returns total committed monthly outflows.
  double get totalMonthlyOutflows =>
      essentialExpenses + discretionaryExpenses + monthlyEmi + declaredSavings;

  FinancialProfile copyWith({
    double? monthlyIncome,
    double? essentialExpenses,
    double? discretionaryExpenses,
    double? monthlyEmi,
    double? declaredSavings,
    double? emergencySavings,
    int? emergencyTargetMonths,
    DateTime? updatedAt,
  }) {
    return FinancialProfile(
      monthlyIncome: math.max(0.0, monthlyIncome ?? this.monthlyIncome),
      essentialExpenses:
          math.max(0.0, essentialExpenses ?? this.essentialExpenses),
      discretionaryExpenses:
          math.max(0.0, discretionaryExpenses ?? this.discretionaryExpenses),
      monthlyEmi: math.max(0.0, monthlyEmi ?? this.monthlyEmi),
      declaredSavings:
          math.max(0.0, declaredSavings ?? this.declaredSavings),
      emergencySavings:
          math.max(0.0, emergencySavings ?? this.emergencySavings),
      emergencyTargetMonths: math.max(
        1,
        emergencyTargetMonths ?? this.emergencyTargetMonths,
      ),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const empty = FinancialProfile();
}
