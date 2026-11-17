import 'financial_profile.dart';

/// Computed snapshot of a user's monthly financial cash flow.
class FinancialOverview {
  const FinancialOverview({
    required this.monthlyIncome,
    required this.essentialExpenses,
    required this.discretionaryExpenses,
    required this.monthlyEmi,
    required this.declaredSavings,
    required this.unallocatedBalance,
    required this.declaredSavingsRate,
    required this.emiShare,
    required this.isConfigured,
  });

  final double monthlyIncome;
  final double essentialExpenses;
  final double discretionaryExpenses;
  final double monthlyEmi;
  final double declaredSavings;

  /// Unallocated Balance = Monthly Income - Essential Expenses - Discretionary Expenses - EMI Obligations - Declared Savings Contribution
  final double unallocatedBalance;

  /// Declared Savings Rate = Declared Savings Contribution / Monthly Income × 100 (0.0% if income <= 0)
  final double declaredSavingsRate;

  /// EMI Share = Monthly EMI Obligations / Monthly Income × 100 (0.0% if income <= 0)
  /// Note: Transparently labeled as user-declared EMI share, never formal credit underwriting DTI.
  final double emiShare;

  final bool isConfigured;

  /// True if outflows exceed income, resulting in a monthly shortfall.
  bool get isDeficit => unallocatedBalance < -0.01;

  /// True if inflows exceed outflows, leaving a surplus.
  bool get isSurplus => unallocatedBalance > 0.01;

  /// True if inflows match outflows within a 1-rupee rounding window.
  bool get isBalanced => !isDeficit && !isSurplus;

  /// Total monthly declared outflows.
  double get totalOutflows =>
      essentialExpenses + discretionaryExpenses + monthlyEmi + declaredSavings;

  /// Proportion of essential expenses to total income.
  double get essentialShare =>
      monthlyIncome > 0 ? (essentialExpenses / monthlyIncome * 100.0) : 0.0;

  /// Proportion of discretionary expenses to total income.
  double get discretionaryShare =>
      monthlyIncome > 0 ? (discretionaryExpenses / monthlyIncome * 100.0) : 0.0;

  /// Static pure calculation method from profile.
  static FinancialOverview fromProfile(FinancialProfile profile) {
    final income = profile.monthlyIncome;
    final essential = profile.essentialExpenses;
    final discretionary = profile.discretionaryExpenses;
    final emi = profile.monthlyEmi;
    final savings = profile.declaredSavings;

    final unallocated = income - essential - discretionary - emi - savings;

    final savingsRate = income > 0 ? (savings / income * 100.0) : 0.0;
    final emiShare = income > 0 ? (emi / income * 100.0) : 0.0;

    return FinancialOverview(
      monthlyIncome: income,
      essentialExpenses: essential,
      discretionaryExpenses: discretionary,
      monthlyEmi: emi,
      declaredSavings: savings,
      unallocatedBalance: unallocated,
      declaredSavingsRate: savingsRate,
      emiShare: emiShare,
      isConfigured: profile.isConfigured,
    );
  }
}
