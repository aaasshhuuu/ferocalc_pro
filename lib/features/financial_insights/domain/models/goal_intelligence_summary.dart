import 'dart:math' as math;
import '../../../goals/domain/models/financial_goal.dart';
import 'financial_overview.dart';

/// Aggregated intelligence and affordability analysis across stored financial goals.
class GoalIntelligenceSummary {
  const GoalIntelligenceSummary({
    required this.allGoals,
    required this.activeGoals,
    required this.completedGoals,
    required this.pausedGoals,
    required this.totalTargetAmount,
    required this.totalAccumulatedSavings,
    required this.overallProgressPercent,
    required this.aggregateMonthlyContribution,
    required this.approachingGoals,
    required this.atRiskGoals,
    required this.unallocatedMonthlyBalance,
    required this.hasCashFlowProfile,
  });

  final List<FinancialGoal> allGoals;
  final List<FinancialGoal> activeGoals;
  final List<FinancialGoal> completedGoals;
  final List<FinancialGoal> pausedGoals;

  /// Combined target amount across active goals.
  final double totalTargetAmount;

  /// Combined accumulated savings across active goals.
  final double totalAccumulatedSavings;

  /// Overall weighted progress percentage across active goals (0 to 100%).
  final double overallProgressPercent;

  /// Sum of required monthly contributions to meet all active goals on schedule.
  final double aggregateMonthlyContribution;

  /// Active goals whose target date is within 90 days.
  final List<FinancialGoal> approachingGoals;

  /// Active goals flagged as at-risk by the goal engine (e.g. past due or nearing target with low progress).
  final List<FinancialGoal> atRiskGoals;

  /// User's unallocated monthly balance from Cash Flow profile.
  final double unallocatedMonthlyBalance;

  /// Whether user has configured their cash flow profile.
  final bool hasCashFlowProfile;

  /// Affordability check: whether monthly unallocated cash flow covers all active goal contributions.
  bool get isAffordable =>
      hasCashFlowProfile &&
      unallocatedMonthlyBalance >= aggregateMonthlyContribution;

  /// Surplus cash flow remaining after covering all active goal contributions.
  double get affordabilitySurplus =>
      math.max(0.0, unallocatedMonthlyBalance - aggregateMonthlyContribution);

  /// Monthly cash flow gap needed to fully support all active goal SIPs.
  double get affordabilityDeficit =>
      math.max(0.0, aggregateMonthlyContribution - unallocatedMonthlyBalance);

  static GoalIntelligenceSummary fromGoalsAndOverview({
    required List<FinancialGoal> goals,
    required FinancialOverview overview,
  }) {
    final active = <FinancialGoal>[];
    final completed = <FinancialGoal>[];
    final paused = <FinancialGoal>[];
    final approaching = <FinancialGoal>[];
    final atRisk = <FinancialGoal>[];

    double totalTarget = 0.0;
    double totalSavings = 0.0;
    double aggregateMonthly = 0.0;

    final now = DateTime.now();

    for (final goal in goals) {
      if (goal.isCompleted) {
        completed.add(goal);
      } else if (goal.status == GoalStatus.paused) {
        paused.add(goal);
      } else {
        active.add(goal);
        totalTarget += goal.targetAmount;
        totalSavings += goal.currentSavings;
        aggregateMonthly += goal.monthlyContribution;

        // Approaching target date within 90 days
        final daysLeft = goal.targetDate.difference(now).inDays;
        if (daysLeft <= 90 && daysLeft >= 0) {
          approaching.add(goal);
        }

        // At risk based on domain model's deterministic evaluation
        if (goal.isAtRisk) {
          atRisk.add(goal);
        }
      }
    }

    final overallProgress = totalTarget > 0
        ? ((totalSavings / totalTarget) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    return GoalIntelligenceSummary(
      allGoals: goals,
      activeGoals: active,
      completedGoals: completed,
      pausedGoals: paused,
      totalTargetAmount: totalTarget,
      totalAccumulatedSavings: totalSavings,
      overallProgressPercent: overallProgress,
      aggregateMonthlyContribution: aggregateMonthly,
      approachingGoals: approaching,
      atRiskGoals: atRisk,
      unallocatedMonthlyBalance: overview.unallocatedBalance,
      hasCashFlowProfile: overview.isConfigured,
    );
  }
}
