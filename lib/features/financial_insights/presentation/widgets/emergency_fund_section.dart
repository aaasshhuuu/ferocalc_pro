import 'package:flutter/material.dart';

import '../../../../core/widgets/glassmorphic_card.dart';
import '../../domain/models/emergency_fund_insight.dart';
import '../../domain/services/financial_insights_engine.dart';

/// Section C: Emergency Fund Planner & Runway Insights
class EmergencyFundSection extends StatelessWidget {
  const EmergencyFundSection({
    Key? key,
    required this.insight,
    required this.onTargetMonthsChanged,
    required this.onEditProfile,
    required this.onOpenGoalPlanner,
  }) : super(key: key);

  final EmergencyFundInsight insight;
  final ValueChanged<int> onTargetMonthsChanged;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenGoalPlanner;

  static const Color gold = Color(0xFFC9A96E);
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color cyan = Color(0xFF00D2D3);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final progressRatio = (insight.fundingPercent / 100.0).clamp(0.0, 1.0);
    final coverageText = insight.hasNoEssentialExpenses
        ? 'Expenses Needed'
        : '${insight.coverageMonths.toStringAsFixed(1)} Months';

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
                  Icon(Icons.health_and_safety_outlined, size: 20, color: emerald),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emergency Fund Planner',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 16, color: gold),
              label: const Text(
                'Adjust Savings',
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
                // Highlight Runway Banner
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: emerald.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: emerald,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Runway Coverage: ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              Text(
                                coverageText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: emerald,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            insight.hasNoEssentialExpenses
                                ? 'Add monthly essential living expenses in Cash Flow to compute exact runway months.'
                                : (insight.isTargetMet
                                    ? 'Target fulfilled! You have full liquid coverage for unexpected emergencies.'
                                    : 'Current liquid savings provide ${insight.coverageMonths.toStringAsFixed(1)} months of essential living runway.'),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Target Selector Chips
                Row(
                  children: [
                    Text(
                      'Target Months:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [3, 6, 9, 12].map((m) {
                            final isSel = insight.targetMonths == m;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  '$m Mos${m == 6 ? ' (Std)' : ''}',
                                ),
                                selected: isSel,
                                selectedColor: gold.withOpacity(0.25),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel
                                      ? (isDark ? Colors.white : const Color(0xFF8B6B23))
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                onSelected: (sel) {
                                  if (sel) onTargetMonthsChanged(m);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Metrics Row: Liquid Savings, Target, Gap
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricBlock(
                        context,
                        label: 'Liquid Savings',
                        value: FinancialInsightsEngine.formatINR(
                          insight.currentSavings,
                        ),
                        color: cyan,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricBlock(
                        context,
                        label: 'Target (${insight.targetMonths}M)',
                        value: insight.hasNoEssentialExpenses
                            ? '—'
                            : FinancialInsightsEngine.formatINR(
                                insight.targetAmount,
                              ),
                        color: gold,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricBlock(
                        context,
                        label: 'Remaining Gap',
                        value: insight.hasNoEssentialExpenses
                            ? '—'
                            : FinancialInsightsEngine.formatINR(insight.gap),
                        color: insight.gap > 0 ? amber : emerald,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fund Progress',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        Text(
                          '${insight.fundingPercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: insight.isTargetMet ? emerald : gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressRatio,
                        minHeight: 8,
                        backgroundColor:
                            isDark ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          insight.isTargetMet ? emerald : gold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Educational notice
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Guideline: Financial planners typically recommend 3 to 6 months of essential living expenses parked in liquid instruments (savings accounts or liquid mutual funds). These calculations are educational heuristics and do not constitute guaranteed financial advice.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBlock(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
