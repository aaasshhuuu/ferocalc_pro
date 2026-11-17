import 'package:intl/intl.dart';

import '../../../goals/domain/models/financial_goal.dart';
import '../../../history/data/models/calculation_history_entry.dart';
import '../models/emergency_fund_insight.dart';
import '../models/financial_overview.dart';
import '../models/financial_profile.dart';
import '../models/goal_intelligence_summary.dart';
import '../models/habit_insight.dart';
import '../models/saved_calculations_summary.dart';

/// Centralized, transparent, deterministic financial calculations and insights engine.
///
/// Rules:
/// - Pure mathematical and rule-based methods only.
/// - Never hallucinates transactions, bank records, or credit scores.
/// - No LLM or generative AI dependencies.
/// - Safely handles zero income, negative balances, and missing inputs.
class FinancialInsightsEngine {
  static final NumberFormat _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Formats INR currency cleanly without trailing decimals.
  static String formatINR(num amount) {
    return _inrFormatter.format(amount.round());
  }

  /// Calculates the monthly cash flow overview snapshot.
  static FinancialOverview computeOverview(FinancialProfile profile) {
    return FinancialOverview.fromProfile(profile);
  }

  /// Calculates emergency fund coverage, target, and gap.
  static EmergencyFundInsight computeEmergencyFund(
    FinancialProfile profile, {
    int? customTargetMonths,
  }) {
    return EmergencyFundInsight.fromProfile(
      profile,
      customTargetMonths: customTargetMonths,
    );
  }

  /// Aggregates financial goal planner data and computes cash-flow affordability.
  static GoalIntelligenceSummary computeGoalIntelligence({
    required List<FinancialGoal> goals,
    required FinancialOverview overview,
  }) {
    return GoalIntelligenceSummary.fromGoalsAndOverview(
      goals: goals,
      overview: overview,
    );
  }

  /// Aggregates non-sensitive calculation history summaries.
  static SavedCalculationsSummary computeSavedCalculations(
    List<CalculationHistoryEntry> history,
  ) {
    return SavedCalculationsSummary.fromHistory(history);
  }

  /// Evaluates deterministic rule-based financial habit insights.
  static List<HabitInsight> generateHabitInsights({
    required FinancialProfile profile,
    required FinancialOverview overview,
    required EmergencyFundInsight emergencyFund,
    required GoalIntelligenceSummary goalSummary,
  }) {
    final insights = <HabitInsight>[];

    // 1. Cash Flow Balance Insight
    if (!profile.isConfigured) {
      insights.add(
        const HabitInsight(
          id: 'cash_flow_unconfigured',
          type: HabitInsightType.cashFlowBalance,
          title: 'Cash Flow Profile Needed',
          calculatedValue: 'Setup Required',
          explanation:
              'Configure your monthly income and expenses to unlock instant cash flow surplus and savings rate insights.',
          disclaimer:
              'Calculations are performed strictly on-device using user-declared figures without linking bank accounts.',
          severity: InsightSeverity.info,
          actionLabel: 'Set Up Cash Flow',
        ),
      );
    } else if (overview.isDeficit) {
      insights.add(
        HabitInsight(
          id: 'cash_flow_deficit',
          type: HabitInsightType.cashFlowBalance,
          title: 'Monthly Cash Flow Deficit',
          calculatedValue: '-${formatINR(overview.unallocatedBalance.abs())}/mo',
          explanation:
              'Your declared monthly outflows (expenses, EMIs, and savings) exceed your take-home income by ${formatINR(overview.unallocatedBalance.abs())}. This deficit must be funded from existing reserves or borrowing.',
          disclaimer:
              'Based purely on user-declared figures. Actual transaction feeds are not tracked.',
          severity: InsightSeverity.alert,
          actionLabel: 'Review Discretionary Spending',
        ),
      );
    } else if (overview.isSurplus) {
      insights.add(
        HabitInsight(
          id: 'cash_flow_surplus',
          type: HabitInsightType.cashFlowBalance,
          title: 'Monthly Cash Flow Surplus',
          calculatedValue: '+${formatINR(overview.unallocatedBalance)}/mo',
          explanation:
              'You retain ${formatINR(overview.unallocatedBalance)} unallocated each month after covering all essential living costs, discretionary spending, EMIs, and declared savings contributions.',
          disclaimer:
              'Based on user-declared figures. Unallocated funds may vary month to month.',
          severity: InsightSeverity.positive,
          actionLabel: 'Explore High-Yield FDs',
          actionRoute: '/smart-fd-discovery',
        ),
      );
    } else {
      insights.add(
        const HabitInsight(
          id: 'cash_flow_balanced',
          type: HabitInsightType.cashFlowBalance,
          title: 'Zero-Based Budget Allocation',
          calculatedValue: '₹0 Unallocated',
          explanation:
              'Every rupee of your monthly take-home income is accounted for across expenses, debt obligations, and savings.',
          disclaimer:
              'Based on user-entered budget figures. Review periodically as income changes.',
          severity: InsightSeverity.info,
        ),
      );
    }

    // 2. Declared Savings Rate Insight
    if (overview.monthlyIncome > 0) {
      final rate = overview.declaredSavingsRate;
      if (rate >= 20.0) {
        insights.add(
          HabitInsight(
            id: 'savings_rate_strong',
            type: HabitInsightType.savingsRate,
            title: 'Strong Savings Habit',
            calculatedValue: '${rate.toStringAsFixed(1)}% of Income',
            explanation:
                'You allocate ${formatINR(overview.declaredSavings)} monthly to wealth building (${rate.toStringAsFixed(1)}% of take-home pay). This meets or exceeds the traditional 20% savings rule of thumb.',
            disclaimer:
                'Calculated as declared monthly savings divided by take-home income. Assumes regular monthly discipline.',
            severity: InsightSeverity.positive,
            actionLabel: 'Plan Financial Goals',
            actionRoute: '/calculator/goal',
          ),
        );
      } else if (rate >= 10.0) {
        insights.add(
          HabitInsight(
            id: 'savings_rate_moderate',
            type: HabitInsightType.savingsRate,
            title: 'Moderate Savings Rate',
            calculatedValue: '${rate.toStringAsFixed(1)}% of Income',
            explanation:
                'You save ${formatINR(overview.declaredSavings)} per month (${rate.toStringAsFixed(1)}% of income). Increasing your allocation by 5% could accelerate your long-term milestones.',
            disclaimer:
                'User-entered figures. Standard benchmarks suggest working towards a 20% savings rate.',
            severity: InsightSeverity.info,
            actionLabel: 'Simulate Goal SIP',
            actionRoute: '/calculator/sip',
          ),
        );
      } else if (rate > 0.0) {
        insights.add(
          HabitInsight(
            id: 'savings_rate_low',
            type: HabitInsightType.savingsRate,
            title: 'Low Declared Savings Allocation',
            calculatedValue: '${rate.toStringAsFixed(1)}% of Income',
            explanation:
                'Your declared monthly savings allocation is ${rate.toStringAsFixed(1)}%. Financial planners generally suggest aiming for 15-20% to stay ahead of inflation.',
            disclaimer:
                'Calculated from user-provided inputs. Individual circumstances and liabilities vary.',
            severity: InsightSeverity.warning,
            actionLabel: 'Adjust Budget',
          ),
        );
      } else {
        insights.add(
          const HabitInsight(
            id: 'savings_rate_zero',
            type: HabitInsightType.savingsRate,
            title: 'No Monthly Savings Declared',
            calculatedValue: '0.0% of Income',
            explanation:
                'You currently have no regular monthly savings or investment contributions declared in your profile.',
            disclaimer:
                'User-declared inputs. Even small recurring SIPs can build substantial compounding over time.',
            severity: InsightSeverity.warning,
            actionLabel: 'Start SIP Calculator',
            actionRoute: '/calculator/sip',
          ),
        );
      }
    }

    // 3. Emergency Reserve Readiness Insight
    if (emergencyFund.hasNoEssentialExpenses) {
      insights.add(
        const HabitInsight(
          id: 'emergency_needs_expense_input',
          type: HabitInsightType.emergencyReadiness,
          title: 'Emergency Fund Baseline Needed',
          calculatedValue: 'Expenses Needed',
          explanation:
              'Declare your monthly essential living expenses in Cash Flow to calculate your emergency fund requirement.',
          disclaimer:
              'Emergency fund targets are typically sized as 3 to 6 months of essential living expenses.',
          severity: InsightSeverity.info,
          actionLabel: 'Set Essential Expenses',
        ),
      );
    } else {
      final coverage = emergencyFund.coverageMonths;
      if (coverage >= emergencyFund.targetMonths) {
        insights.add(
          HabitInsight(
            id: 'emergency_fully_funded',
            type: HabitInsightType.emergencyReadiness,
            title: 'Emergency Fund Fully Funded',
            calculatedValue: '${coverage.toStringAsFixed(1)} Months Covered',
            explanation:
                'Your current liquid emergency savings of ${formatINR(emergencyFund.currentSavings)} cover ${coverage.toStringAsFixed(1)} months of essential living expenses, fulfilling your ${emergencyFund.targetMonths}-month target.',
            disclaimer:
                'Liquid savings are self-reported. Keep reserves in instant-access savings accounts or liquid mutual funds.',
            severity: InsightSeverity.positive,
            actionLabel: 'Explore Fixed Deposits',
            actionRoute: '/smart-fd-discovery',
          ),
        );
      } else if (coverage >= 3.0) {
        insights.add(
          HabitInsight(
            id: 'emergency_moderate',
            type: HabitInsightType.emergencyReadiness,
            title: 'Adequate Emergency Cushion',
            calculatedValue: '${coverage.toStringAsFixed(1)} Months Covered',
            explanation:
                'You have ${coverage.toStringAsFixed(1)} months of essential living cost runway. A remaining gap of ${formatINR(emergencyFund.gap)} will bring you to your full ${emergencyFund.targetMonths}-month target.',
            disclaimer:
                'Self-reported liquid savings vs declared essential expenses. Not a credit evaluation.',
            severity: InsightSeverity.info,
            actionLabel: 'Plan Emergency Goal',
            actionRoute: '/calculator/goal',
          ),
        );
      } else {
        insights.add(
          HabitInsight(
            id: 'emergency_vulnerable',
            type: HabitInsightType.emergencyReadiness,
            title: 'Emergency Reserve Below 3 Months',
            calculatedValue: '${coverage.toStringAsFixed(1)} Months Covered',
            explanation:
                'You currently have ${coverage.toStringAsFixed(1)} months of essential living expenses in reserve (Target: ${emergencyFund.targetMonths} months, Gap: ${formatINR(emergencyFund.gap)}). Prioritize liquid cushion before illiquid commitments.',
            disclaimer:
                'General financial guideline: Maintain at least 3-6 months of essential costs for unplanned events.',
            severity: InsightSeverity.warning,
            actionLabel: 'Set Emergency Target',
            actionRoute: '/calculator/goal',
          ),
        );
      }
    }

    // 4. Debt & EMI Exposure Insight
    if (overview.monthlyIncome > 0) {
      final emiShare = overview.emiShare;
      if (emiShare <= 30.0) {
        insights.add(
          HabitInsight(
            id: 'emi_conservative',
            type: HabitInsightType.emiBurden,
            title: 'Conservative EMI Exposure',
            calculatedValue: '${emiShare.toStringAsFixed(1)}% of Income',
            explanation:
                'Monthly loan EMIs of ${formatINR(overview.monthlyEmi)} consume ${emiShare.toStringAsFixed(1)}% of your take-home pay. Maintaining debt under 30% safeguards cash flow resilience.',
            disclaimer:
                'Calculated purely from user-entered EMI obligations and income. Never represents formal credit underwriting DTI.',
            severity: InsightSeverity.positive,
          ),
        );
      } else if (emiShare <= 50.0) {
        insights.add(
          HabitInsight(
            id: 'emi_moderate',
            type: HabitInsightType.emiBurden,
            title: 'Moderate EMI Commitment',
            calculatedValue: '${emiShare.toStringAsFixed(1)}% of Income',
            explanation:
                'Your declared monthly debt obligations represent ${emiShare.toStringAsFixed(1)}% of your income. Avoid adding high-cost consumer debt without prepaying existing balances.',
            disclaimer:
                'User-declared calculation. Does not incorporate external credit bureau trade lines.',
            severity: InsightSeverity.info,
            actionLabel: 'Prepayment / EMI Calc',
            actionRoute: '/calculator/emi',
          ),
        );
      } else {
        insights.add(
          HabitInsight(
            id: 'emi_heavy',
            type: HabitInsightType.emiBurden,
            title: 'High Debt / EMI Burden',
            calculatedValue: '${emiShare.toStringAsFixed(1)}% of Income',
            explanation:
                'Over half of your take-home income (${emiShare.toStringAsFixed(1)}%) is committed to loan repayments. This leaves limited flexibility for unplanned emergencies.',
            disclaimer:
                'User-declared calculation. Not a formal credit bureau debt-to-income metric.',
            severity: InsightSeverity.alert,
            actionLabel: 'Review Loan Strategy',
            actionRoute: '/calculator/emi',
          ),
        );
      }
    }

    // 5. Goal Contribution Affordability Insight
    if (goalSummary.activeGoals.isNotEmpty) {
      if (!overview.isConfigured) {
        insights.add(
          HabitInsight(
            id: 'goal_affordability_unconfigured',
            type: HabitInsightType.goalAffordability,
            title: 'Goal Funding Affordability',
            calculatedValue:
                '${formatINR(goalSummary.aggregateMonthlyContribution)}/mo Required',
            explanation:
                'You have ${goalSummary.activeGoals.length} active financial goals requiring ${formatINR(goalSummary.aggregateMonthlyContribution)} monthly. Set up your cash flow profile to verify budget affordability.',
            disclaimer:
                'Calculated from Phase 5.0.5 Goal Planner projections and local goal repository.',
            severity: InsightSeverity.info,
            actionLabel: 'Configure Cash Flow',
          ),
        );
      } else if (goalSummary.isAffordable) {
        insights.add(
          HabitInsight(
            id: 'goal_affordability_funded',
            type: HabitInsightType.goalAffordability,
            title: 'Goals Fully Supported by Cash Flow',
            calculatedValue:
                'Affordable (+${formatINR(goalSummary.affordabilitySurplus)}/mo buffer)',
            explanation:
                'Your monthly unallocated balance of ${formatINR(overview.unallocatedBalance)} comfortably funds all ${goalSummary.activeGoals.length} active goals (${formatINR(goalSummary.aggregateMonthlyContribution)}/mo total), leaving an extra ${formatINR(goalSummary.affordabilitySurplus)} safety cushion.',
            disclaimer:
                'Compares user-declared monthly unallocated cash flow with Goal Planner monthly contribution requirements.',
            severity: InsightSeverity.positive,
            actionLabel: 'View Goal Planner',
            actionRoute: '/calculator/goal',
          ),
        );
      } else {
        insights.add(
          HabitInsight(
            id: 'goal_affordability_shortfall',
            type: HabitInsightType.goalAffordability,
            title: 'Goal Contribution Cash Flow Gap',
            calculatedValue:
                'Shortfall of ${formatINR(goalSummary.affordabilityDeficit)}/mo',
            explanation:
                'Your ${goalSummary.activeGoals.length} active goals require ${formatINR(goalSummary.aggregateMonthlyContribution)} monthly, but your unallocated cash flow is ${formatINR(overview.unallocatedBalance)}. Consider extending target dates or trimming discretionary expenses.',
            disclaimer:
                'Calculated as aggregate monthly goal requirement minus monthly unallocated balance.',
            severity: InsightSeverity.warning,
            actionLabel: 'Adjust Goal Targets',
            actionRoute: '/calculator/goal',
          ),
        );
      }
    }

    // 6. 50/30/20 Budget Guideline Insight
    if (overview.monthlyIncome > 0) {
      final needsPercent = overview.essentialShare + overview.emiShare;
      final wantsPercent = overview.discretionaryShare;
      final savingsPercent = overview.declaredSavingsRate;

      insights.add(
        HabitInsight(
          id: 'budget_503020_check',
          type: HabitInsightType.budgetAllocation503020,
          title: '50/30/20 Budget Rule Check',
          calculatedValue:
              'Needs ${needsPercent.toStringAsFixed(0)}% | Wants ${wantsPercent.toStringAsFixed(0)}% | Savings ${savingsPercent.toStringAsFixed(0)}%',
          explanation:
              'Popular personal finance guidelines suggest capping Needs (Essentials + EMIs) at 50%, Wants at 30%, and allocating 20% to Savings. Your profile: Needs ${needsPercent.toStringAsFixed(0)}%, Wants ${wantsPercent.toStringAsFixed(0)}%, Savings ${savingsPercent.toStringAsFixed(0)}%.',
          disclaimer:
              'The 50/30/20 rule is an illustrative budgeting model, not mandatory personal financial advice.',
          severity: InsightSeverity.info,
        ),
      );
    }

    return insights;
  }
}
