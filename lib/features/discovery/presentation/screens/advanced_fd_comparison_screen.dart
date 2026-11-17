import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/discovery_models.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/financial_math.dart' hide CompoundingFrequency;
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';

class AdvancedFdComparisonScreen extends StatelessWidget {
  const AdvancedFdComparisonScreen({
    Key? key,
    required this.selectedMatches,
    required this.criteria,
  }) : super(key: key);

  final List<FdDiscoveryMatch> selectedMatches;
  final FdDiscoveryCriteria criteria;

  static const Color gold = Color(0xFFC9A96E);
  static const Color emerald = Color(0xFF10B981);
  static const Color cyan = Color(0xFF38BDF8);

  void _navigateToCalculator(BuildContext context, FdDiscoveryMatch match) {
    int years = 0;
    int months = 0;
    int days = 0;

    switch (criteria.tenureUnit) {
      case TenureUnit.days:
        days = criteria.tenureValue;
        break;
      case TenureUnit.months:
        years = criteria.tenureValue ~/ 12;
        months = criteria.tenureValue % 12;
        break;
      case TenureUnit.years:
        years = criteria.tenureValue;
        break;
    }

    context.push(
      '/calculator/fd',
      extra: {
        'principal': criteria.depositAmount,
        'interestRate': match.interestRate,
        'years': years,
        'months': months,
        'days': days,
        'isSeniorCitizen': criteria.customerCategory == CustomerCategory.seniorCitizen,
        'bankName': match.bankName,
        'sourceUrl': match.sourceUrl,
        'verifiedAt': match.verifiedAt?.toIso8601String(),
        'compoundingFrequency': match.compoundingFrequency.displayLabel,
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find highest return for comparison delta
    double maxMaturity = 0;
    double minMaturity = double.infinity;
    for (final m in selectedMatches) {
      if (m.estimatedMaturity > maxMaturity) maxMaturity = m.estimatedMaturity;
      if (m.estimatedMaturity < minMaturity) minMaturity = m.estimatedMaturity;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF091422) : Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Side-by-Side Comparison',
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: gold),
            tooltip: 'Data Trust Center',
            onPressed: () => context.push('/trust-center'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Responsive.screenPadding(context),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCommonCriteriaCard(context, isDark, maxMaturity, minMaturity),
                  const SizedBox(height: 16),
                  _buildComparisonMatrix(context, isDark, maxMaturity, minMaturity),
                  const SizedBox(height: 20),
                  _buildDisclaimerCard(context, isDark),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommonCriteriaCard(
    BuildContext context,
    bool isDark,
    double maxMaturity,
    double minMaturity,
  ) {
    final spread = maxMaturity - minMaturity;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132235) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.compare_arrows_rounded, color: gold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Identical Comparison Baseline',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${selectedMatches.length} Options',
                  style: const TextStyle(
                    color: gold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildBaselineChip('Deposit', FinancialMath.formatCurrency(criteria.depositAmount), isDark),
              _buildBaselineChip('Tenure', criteria.formattedTenureLabel, isDark),
              _buildBaselineChip('Category', criteria.customerCategory.label, isDark),
              _buildBaselineChip('Compounding', 'Standard Quarterly', isDark),
            ],
          ),
          if (spread > 10 && selectedMatches.length > 1) ...[
            const Divider(height: 20),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.trending_up, color: emerald, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Max difference across compared options: ',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                ),
                Text(
                  FinancialMath.formatCurrency(spread),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: emerald,
                  ),
                ),
                Text(
                  ' over tenure',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBaselineChip(String label, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonMatrix(
    BuildContext context,
    bool isDark,
    double maxMaturity,
    double minMaturity,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: selectedMatches.map((match) {
          final isBestMaturity = (match.estimatedMaturity - maxMaturity).abs() < 0.01;
          final extraGain = match.estimatedMaturity - minMaturity;

          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF132235) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isBestMaturity ? gold : (isDark ? Colors.white12 : Colors.black12),
                width: isBestMaturity ? 2 : 1,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Column Header
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isBestMaturity
                        ? gold.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF0F1A28) : Colors.grey[100]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isBestMaturity) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: gold,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 10, color: Colors.black),
                                  SizedBox(width: 3),
                                  Text(
                                    'HIGHEST RETURN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              match.bankName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: emerald),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        match.isCallable ? 'Callable (Exit allowed)' : 'Non-Callable (Locked)',
                        style: TextStyle(
                          fontSize: 10,
                          color: match.isCallable ? cyan : Colors.orangeAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Data Rows
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Interest Rate
                      _buildMetricRow(
                        label: 'Interest Rate',
                        value: '${match.interestRate.toStringAsFixed(2)}% p.a.',
                        valueColor: gold,
                        isLarge: true,
                        isDark: isDark,
                      ),
                      const Divider(height: 16),

                      // 2. Estimated Maturity
                      _buildMetricRow(
                        label: 'Estimated Maturity',
                        value: FinancialMath.formatCurrency(match.estimatedMaturity),
                        valueColor: isDark ? Colors.white : Colors.black87,
                        isLarge: true,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 4),

                      // 3. Total Interest
                      _buildMetricRow(
                        label: 'Total Interest',
                        value: '+${FinancialMath.formatCurrency(match.estimatedInterest)}',
                        valueColor: emerald,
                        isDark: isDark,
                      ),

                      if (extraGain > 1 && !isBestMaturity) ...[
                        const SizedBox(height: 2),
                        Text(
                          '(-${FinancialMath.formatCurrency(maxMaturity - match.estimatedMaturity)} vs top option)',
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ],
                      const Divider(height: 16),

                      // 4. Product Details
                      _buildDetailRow('Compounding', match.compoundingFrequency.displayLabel, isDark),
                      const SizedBox(height: 6),
                      _buildDetailRow('Deposit Limits', match.depositRangeLabel, isDark),
                      const SizedBox(height: 6),
                      _buildDetailRow('Matching Slab', match.matchingTenureText, isDark),
                      const SizedBox(height: 6),
                      _buildDetailRow('Effective Date', DateFormatter.formatIsoDate(match.effectiveFrom), isDark),
                      if (match.verifiedAt != null) ...[
                        const SizedBox(height: 6),
                        _buildDetailRow('Verified At', DateFormatter.formatRelative(match.verifiedAt!), isDark),
                      ],
                      const SizedBox(height: 16),

                      // 5. Official Source Link
                      if (match.sourceUrl != null && match.sourceUrl!.isNotEmpty)
                        InkWell(
                          onTap: () => _launchUrl(match.sourceUrl!),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new, size: 12, color: gold),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'View Official Circular',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: gold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // 6. Calculate in Calculator Button
                      ElevatedButton.icon(
                        onPressed: () => _navigateToCalculator(context, match),
                        icon: const Icon(Icons.calculate_outlined, size: 14),
                        label: const Text('Calculate Returns', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required String value,
    required Color valueColor,
    required bool isDark,
    bool isLarge = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 18 : 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132235) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: isDark ? Colors.white70 : Colors.black54),
              const SizedBox(width: 8),
              Text(
                'Financial Calculation Methodology & Disclosure',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• All comparisons use an identical principal amount and exact matching tenure across published official rates.\n'
            '• Compounding calculation uses standard quarterly compounding formula: A = P × (1 + r/4)^(4×t).\n'
            '• Maturity figures are estimates for comparison and do not constitute guaranteed values. Banks may apply specific day-count conventions (365/366) or TDS deductions.\n'
            '• FeroCalc is a mathematical financial calculator and discovery tool, not an investment advisor or deposit broker.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
