import 'package:flutter/material.dart';

import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../goals/domain/models/financial_goal.dart';
import '../../domain/models/goal_intelligence_summary.dart';
import '../../domain/services/financial_insights_engine.dart';

/// Section D: Financial Goal Intelligence & Affordability Analysis
class GoalIntelligenceSection extends StatelessWidget {
  const GoalIntelligenceSection({
    Key? key,
    required this.summary,
    required this.onOpenGoalPlanner,
    required this.onOpenGoalDetail,
    required this.onEditCashFlow,
  }) : super(key: key);

  final GoalIntelligenceSummary summary;
  final VoidCallback onOpenGoalPlanner;
  final ValueChanged<FinancialGoal> onOpenGoalDetail;
  final VoidCallback onEditCashFlow;

  static const Color gold = Color(0xFFC9A96E);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color alertRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.track_changes, size: 20, color: gold),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Goal Intelligence',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onOpenGoalPlanner,
              icon: const Icon(Icons.arrow_forward, size: 16, color: gold),
              label: const Text(
                'Goal Planner',
                style: TextStyle(color: gold, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        GlassmorphicCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // If no goals stored
                if (summary.allGoals.isEmpty) ...[
                  _buildEmptyGoalsState(context, isDark),
                ] else ...[
                  // Summary metrics row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          label: 'Active Goals',
                          value: '${summary.activeGoals.length}',
                          subtext: '${summary.completedGoals.length} completed',
                          color: emerald,
                          icon: Icons.flag_outlined,
                        ),
                      ),
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          label: 'Accumulated',
                          value: FinancialInsightsEngine.formatINR(
                            summary.totalAccumulatedSavings,
                          ),
                          subtext:
                              'of ${FinancialInsightsEngine.formatINR(summary.totalTargetAmount)}',
                          color: gold,
                          icon: Icons.savings_outlined,
                        ),
                      ),
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          label: 'Monthly SIP Req.',
                          value: FinancialInsightsEngine.formatINR(
                            summary.aggregateMonthlyContribution,
                          ),
                          subtext: 'across active goals',
                          color: const Color(0xFF00D2D3),
                          icon: Icons.event_repeat,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Overall progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Overall Portfolio Progress',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          Text(
                            '${summary.overallProgressPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: emerald,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (summary.overallProgressPercent / 100.0)
                              .clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor:
                              isDark ? Colors.white10 : Colors.black12,
                          valueColor: const AlwaysStoppedAnimation<Color>(emerald),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Affordability Insight Box
                  _buildAffordabilityBox(context, isDark),

                  // At-Risk & Approaching Goals
                  if (summary.atRiskGoals.isNotEmpty ||
                      summary.approachingGoals.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildAlertGoalsSection(context, isDark),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyGoalsState(BuildContext context, bool isDark) {
    return Column(
      children: [
        Icon(
          Icons.flag_outlined,
          size: 40,
          color: isDark ? Colors.white30 : Colors.black26,
        ),
        const SizedBox(height: 10),
        const Text(
          'No Financial Goals Configured',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Create milestone goals (home down payment, child education, car, retirement) to measure whether your monthly savings are on track.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: onOpenGoalPlanner,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add a Goal in Planner'),
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAffordabilityBox(BuildContext context, bool isDark) {
    final hasCashFlow = summary.hasCashFlowProfile;
    final isAffordable = summary.isAffordable;
    final req = summary.aggregateMonthlyContribution;
    final unallocated = summary.unallocatedMonthlyBalance;

    final Color boxColor;
    final IconData boxIcon;
    final String title;
    final String explanation;

    if (!hasCashFlow) {
      boxColor = Colors.blueGrey;
      boxIcon = Icons.info_outline;
      title = 'Cash Flow Comparison Available';
      explanation =
          'You need ${FinancialInsightsEngine.formatINR(req)}/mo for active goals. Set up your Cash Flow profile to evaluate whether this fits your unallocated budget.';
    } else if (isAffordable) {
      boxColor = emerald;
      boxIcon = Icons.check_circle_outline;
      title = 'Goals Fully Affordable within Cash Flow';
      explanation =
          'Your monthly unallocated balance (${FinancialInsightsEngine.formatINR(unallocated)}) covers your required goal SIPs (${FinancialInsightsEngine.formatINR(req)}/mo) with a buffer of ${FinancialInsightsEngine.formatINR(summary.affordabilitySurplus)}/mo.';
    } else {
      boxColor = amber;
      boxIcon = Icons.warning_amber_rounded;
      title = 'Monthly Cash Flow Shortfall';
      explanation =
          'Active goals require ${FinancialInsightsEngine.formatINR(req)}/mo, but your unallocated cash flow is ${FinancialInsightsEngine.formatINR(unallocated)}. Deficit: ${FinancialInsightsEngine.formatINR(summary.affordabilityDeficit)}/mo. Consider extending target dates or increasing monthly savings.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: boxColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(boxIcon, color: boxColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: boxColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  explanation,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                if (!hasCashFlow) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: onEditCashFlow,
                    child: const Text(
                      'Configure Cash Flow Profile →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: gold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertGoalsSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.atRiskGoals.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: alertRed, size: 16),
              const SizedBox(width: 6),
              Text(
                'At-Risk Goals (${summary.atRiskGoals.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: alertRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...summary.atRiskGoals.take(2).map((goal) => _buildGoalItem(context, goal, isAtRisk: true)),
          const SizedBox(height: 8),
        ],
        if (summary.approachingGoals.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.schedule, color: amber, size: 16),
              const SizedBox(width: 6),
              Text(
                'Approaching Target Date (${summary.approachingGoals.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...summary.approachingGoals.take(2).map((goal) => _buildGoalItem(context, goal, isAtRisk: false)),
        ],
      ],
    );
  }

  Widget _buildGoalItem(
    BuildContext context,
    FinancialGoal goal, {
    required bool isAtRisk,
  }) {
    return InkWell(
      onTap: () => onOpenGoalDetail(goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: (isAtRisk ? alertRed : amber).withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (isAtRisk ? alertRed : amber).withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              goal.category.icon,
              size: 16,
              color: isAtRisk ? alertRed : amber,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                goal.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${goal.progressPercent.toStringAsFixed(0)}% • ${goal.remainingTimeText}',
              style: TextStyle(
                fontSize: 11,
                color: isAtRisk ? alertRed : amber,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required String subtext,
    required Color color,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
