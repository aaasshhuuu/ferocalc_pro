import 'package:flutter/material.dart';

import '../../../../core/widgets/glassmorphic_card.dart';
import '../../domain/models/financial_overview.dart';
import '../../domain/models/financial_profile.dart';
import '../../domain/services/financial_insights_engine.dart';
import 'cash_flow_distribution_chart.dart';

/// Section A & B: Financial Overview & Cash Flow Planner Summary
class FinancialOverviewSection extends StatelessWidget {
  const FinancialOverviewSection({
    Key? key,
    required this.overview,
    required this.profile,
    required this.onEditCashFlow,
  }) : super(key: key);

  final FinancialOverview overview;
  final FinancialProfile profile;
  final VoidCallback onEditCashFlow;

  static const Color gold = Color(0xFFC9A96E);
  static const Color emerald = Color(0xFF10B981);
  static const Color alertRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!overview.isConfigured) {
      return _buildEmptyCashFlowCard(context, isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Edit Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.dashboard_customize_outlined, size: 20, color: gold),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Financial Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onEditCashFlow,
              icon: const Icon(Icons.edit_outlined, size: 16, color: gold),
              label: const Text(
                'Edit Cash Flow',
                style: TextStyle(color: gold, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Primary Snapshot Card
        GlassmorphicCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Monthly Income & Remaining Unallocated Balance
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        label: 'Take-Home Income',
                        value: FinancialInsightsEngine.formatINR(
                          overview.monthlyIncome,
                        ),
                        subtext: 'Net monthly earnings',
                        color: gold,
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        label: overview.isDeficit
                            ? 'Monthly Deficit'
                            : 'Unallocated Balance',
                        value: overview.isDeficit
                            ? '-${FinancialInsightsEngine.formatINR(overview.unallocatedBalance.abs())}'
                            : FinancialInsightsEngine.formatINR(
                                overview.unallocatedBalance,
                              ),
                        subtext: overview.isDeficit
                            ? 'Outflows exceed income'
                            : (overview.isSurplus
                                ? 'Available monthly surplus'
                                : 'Exact balanced budget'),
                        color: overview.isDeficit
                            ? alertRed
                            : (overview.isSurplus ? emerald : Colors.grey),
                        icon: overview.isDeficit
                            ? Icons.trending_down
                            : Icons.savings_outlined,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Middle Row: Savings Rate & User-Declared EMI Share
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        label: 'Declared Savings Rate',
                        value: '${overview.declaredSavingsRate.toStringAsFixed(1)}%',
                        subtext:
                            '${FinancialInsightsEngine.formatINR(overview.declaredSavings)} saved/mo',
                        color: overview.declaredSavingsRate >= 20.0
                            ? emerald
                            : (overview.declaredSavingsRate >= 10.0
                                ? const Color(0xFF00D2D3)
                                : Colors.amber),
                        icon: Icons.show_chart,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        context,
                        label: 'EMI Share of Income',
                        value: '${overview.emiShare.toStringAsFixed(1)}%',
                        subtext:
                            '${FinancialInsightsEngine.formatINR(overview.monthlyEmi)} committed EMIs',
                        color: overview.emiShare > 50.0
                            ? alertRed
                            : (overview.emiShare > 30.0
                                ? Colors.amber
                                : emerald),
                        icon: Icons.account_balance_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Visual Chart
                CashFlowDistributionChart(overview: overview),
                const SizedBox(height: 16),

                // Outflow breakdown chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildOutflowChip(
                      label: 'Essentials',
                      amount: overview.essentialExpenses,
                      color: const Color(0xFF3B82F6),
                    ),
                    _buildOutflowChip(
                      label: 'Discretionary',
                      amount: overview.discretionaryExpenses,
                      color: const Color(0xFFF59E0B),
                    ),
                    _buildOutflowChip(
                      label: 'EMIs',
                      amount: overview.monthlyEmi,
                      color: alertRed,
                    ),
                    _buildOutflowChip(
                      label: 'Investments',
                      amount: overview.declaredSavings,
                      color: emerald,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Transparent Formula & Disclaimer Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.grey.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Calculation Transparency & Notice',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Unallocated Balance = Income - Essentials - Discretionary - EMIs - Savings\n'
                        '• Declared Savings Rate = Monthly Savings / Monthly Income × 100\n'
                        '• EMI Share = Monthly EMIs / Monthly Income × 100\n'
                        'Notice: EMI Share is a heuristic ratio based on self-reported entries and is NOT a formal credit underwriting Debt-to-Income (DTI) ratio. Calculations are based on user-provided inputs, stored strictly on-device, and not verified against banking records.',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.4,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCashFlowCard(BuildContext context, bool isDark) {
    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 36,
                color: gold,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Set Up Your Cash Flow Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your monthly take-home income and expenses to unlock instant cash flow surplus analysis, savings rates, emergency runway, and goal affordability checks.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onEditCashFlow,
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Configure Cash Flow (2 Mins)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '100% private. Data never leaves your device.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
      label: '$label: $value, $subtext',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOutflowChip({
    required String label,
    required double amount,
    required Color color,
  }) {
    return Semantics(
      label: '$label: ${FinancialInsightsEngine.formatINR(amount)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$label: ${FinancialInsightsEngine.formatINR(amount)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
