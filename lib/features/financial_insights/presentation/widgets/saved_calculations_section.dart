import 'package:flutter/material.dart';

import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../history/data/models/calculation_history_entry.dart';
import '../../domain/models/saved_calculations_summary.dart';

/// Section F: Saved Calculations Insights & Quick Tool Access
class SavedCalculationsSection extends StatelessWidget {
  const SavedCalculationsSection({
    Key? key,
    required this.summary,
    required this.onViewAllHistory,
    required this.onOpenCalculation,
    required this.onLaunchCalculator,
  }) : super(key: key);

  final SavedCalculationsSummary summary;
  final VoidCallback onViewAllHistory;
  final ValueChanged<CalculationHistoryEntry> onOpenCalculation;
  final ValueChanged<String> onLaunchCalculator;

  static const Color gold = Color(0xFFC9A96E);
  static const Color emerald = Color(0xFF10B981);

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
                  Icon(Icons.history, size: 20, color: gold),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved Calculations',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (summary.totalCount > 0)
              TextButton.icon(
                onPressed: onViewAllHistory,
                icon: const Icon(Icons.arrow_forward, size: 16, color: gold),
                label: const Text(
                  'View All',
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
                // Summary Metrics
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        label: 'Total Saved',
                        value: '${summary.totalCount}',
                        subtext: 'Local calculation snapshots',
                        color: gold,
                        icon: Icons.bookmark_border,
                      ),
                    ),
                    if (summary.mostFrequentCategory != null)
                      Expanded(
                        child: _buildMetricTile(
                          context,
                          label: 'Top Category',
                          value: summary.mostFrequentCategory!,
                          subtext:
                              '${summary.categoryFrequencies[summary.mostFrequentCategory] ?? 0} saved calculations',
                          color: emerald,
                          icon: Icons.category_outlined,
                        ),
                      ),
                  ],
                ),

                // Recently Used Categories Chips
                if (summary.recentlyUsedCategories.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: summary.recentlyUsedCategories.map((cat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: gold.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: gold.withOpacity(0.2)),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Recent Calculations List
                if (summary.recentEntries.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text(
                    'Recent Calculations',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: summary.recentEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, idx) {
                      final entry = summary.recentEntries[idx];
                      return _buildRecentItem(context, entry, isDark);
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'No calculations saved yet. Run and save a calculation to see history here.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],

                const Divider(height: 24),

                // Quick Access Tools Grid
                const Text(
                  'Quick Access Calculators',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildToolChip('SIP Calc', 'sip', Icons.trending_up),
                    _buildToolChip('EMI Calc', 'emi', Icons.home_outlined),
                    _buildToolChip('FD Calc', 'fd', Icons.account_balance),
                    _buildToolChip('PPF Calc', 'ppf', Icons.savings_outlined),
                    _buildToolChip('Income Tax', 'income_tax', Icons.receipt_long),
                    _buildToolChip('Goal Planner', 'goal', Icons.flag_outlined),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentItem(
    BuildContext context,
    CalculationHistoryEntry entry,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => onOpenCalculation(entry),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calculate_outlined, size: 16, color: gold),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${entry.primaryResultLabel}: ${entry.primaryResultValue}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              entry.formattedDateTime,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildToolChip(String label, String calculatorId, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: gold),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => onLaunchCalculator(calculatorId),
      backgroundColor: gold.withOpacity(0.08),
      side: BorderSide(color: gold.withOpacity(0.2)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
