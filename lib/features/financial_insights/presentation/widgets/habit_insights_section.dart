import 'package:flutter/material.dart';

import '../../../../core/widgets/glassmorphic_card.dart';
import '../../domain/models/habit_insight.dart';

/// Section E: Savings & Financial Habits Insights Cards
class HabitInsightsSection extends StatelessWidget {
  const HabitInsightsSection({
    Key? key,
    required this.insights,
    required this.onActionTap,
  }) : super(key: key);

  final List<HabitInsight> insights;
  final ValueChanged<HabitInsight> onActionTap;

  static const Color gold = Color(0xFFC9A96E);

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lightbulb_outline, size: 20, color: gold),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Financial Habits & Insights',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: insights.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, index) {
            final insight = insights[index];
            return _buildInsightCard(context, insight, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildInsightCard(
    BuildContext context,
    HabitInsight insight,
    bool isDark,
  ) {
    final severityColor = insight.severity.color;
    final severityIcon = insight.severity.icon;

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Severity Icon, Title, and Calculated Value Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(severityIcon, size: 18, color: severityColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: severityColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          insight.calculatedValue,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: severityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Explanation
            Text(
              insight.explanation,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),

            // Assumptions / Disclaimers
            Text(
              'Note: ${insight.disclaimer}',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),

            // Action Button if available
            if (insight.actionLabel != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onActionTap(insight),
                  icon: const Icon(Icons.arrow_forward, size: 14, color: gold),
                  label: Text(
                    insight.actionLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: gold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
