import 'package:flutter/material.dart';

import '../../domain/models/financial_overview.dart';
import '../../domain/services/financial_insights_engine.dart';

/// Clean, responsive visual breakdown of monthly cash flow allocations.
class CashFlowDistributionChart extends StatelessWidget {
  const CashFlowDistributionChart({
    Key? key,
    required this.overview,
  }) : super(key: key);

  final FinancialOverview overview;

  static const Color colorEssential = Color(0xFF3B82F6); // Blue
  static const Color colorDiscretionary = Color(0xFFF59E0B); // Amber
  static const Color colorEmi = Color(0xFFEF4444); // Red
  static const Color colorSavings = Color(0xFF10B981); // Emerald Green
  static const Color colorSurplus = Color(0xFF00D2D3); // Cyan
  static const Color colorDeficit = Color(0xFFDC2626); // Dark Red

  @override
  Widget build(BuildContext context) {
    final income = overview.monthlyIncome;
    final totalOutflows = overview.totalOutflows;

    if (income <= 0 && totalOutflows <= 0) {
      return const SizedBox.shrink();
    }

    // Base denominator for proportions: either total income or total outflows if exceeding income
    final double denominator = income > 0
        ? (totalOutflows > income ? totalOutflows : income)
        : (totalOutflows > 0 ? totalOutflows : 1.0);

    final double essentialRatio =
        (overview.essentialExpenses / denominator).clamp(0.0, 1.0);
    final double discretionaryRatio =
        (overview.discretionaryExpenses / denominator).clamp(0.0, 1.0);
    final double emiRatio =
        (overview.monthlyEmi / denominator).clamp(0.0, 1.0);
    final double savingsRatio =
        (overview.declaredSavings / denominator).clamp(0.0, 1.0);

    final double surplusRatio = overview.isSurplus && income > 0
        ? (overview.unallocatedBalance / denominator).clamp(0.0, 1.0)
        : 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly Cash Flow Breakdown',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // Horizontal Segmented Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 16,
            width: double.infinity,
            color: isDark ? Colors.white10 : Colors.black12,
            child: Row(
              children: [
                if (essentialRatio > 0)
                  Flexible(
                    flex: (essentialRatio * 1000).toInt(),
                    child: Container(color: colorEssential),
                  ),
                if (discretionaryRatio > 0)
                  Flexible(
                    flex: (discretionaryRatio * 1000).toInt(),
                    child: Container(color: colorDiscretionary),
                  ),
                if (emiRatio > 0)
                  Flexible(
                    flex: (emiRatio * 1000).toInt(),
                    child: Container(color: colorEmi),
                  ),
                if (savingsRatio > 0)
                  Flexible(
                    flex: (savingsRatio * 1000).toInt(),
                    child: Container(color: colorSavings),
                  ),
                if (surplusRatio > 0)
                  Flexible(
                    flex: (surplusRatio * 1000).toInt(),
                    child: Container(color: colorSurplus),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Deficit Warning Bar if negative
        if (overview.isDeficit) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorDeficit.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorDeficit.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: colorDeficit, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Monthly Deficit: ${FinancialInsightsEngine.formatINR(overview.unallocatedBalance.abs())} (Outflows exceed income)',
                    style: const TextStyle(
                      color: colorDeficit,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildLegendItem(
              label: 'Essentials',
              amount: overview.essentialExpenses,
              ratio: essentialRatio,
              color: colorEssential,
            ),
            _buildLegendItem(
              label: 'Discretionary',
              amount: overview.discretionaryExpenses,
              ratio: discretionaryRatio,
              color: colorDiscretionary,
            ),
            _buildLegendItem(
              label: 'EMIs',
              amount: overview.monthlyEmi,
              ratio: emiRatio,
              color: colorEmi,
            ),
            _buildLegendItem(
              label: 'Savings',
              amount: overview.declaredSavings,
              ratio: savingsRatio,
              color: colorSavings,
            ),
            if (overview.isSurplus)
              _buildLegendItem(
                label: 'Surplus',
                amount: overview.unallocatedBalance,
                ratio: surplusRatio,
                color: colorSurplus,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required String label,
    required double amount,
    required double ratio,
    required Color color,
  }) {
    final percent = (ratio * 100.0).toStringAsFixed(0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$label: ${FinancialInsightsEngine.formatINR(amount)} ($percent%)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
