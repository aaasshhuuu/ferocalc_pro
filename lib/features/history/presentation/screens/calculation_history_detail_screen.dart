import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/repositories/calculation_history_repository.dart';

class CalculationHistoryDetailScreen extends StatelessWidget {
  final CalculationHistoryEntry entry;

  const CalculationHistoryDetailScreen({
    Key? key,
    required this.entry,
  }) : super(key: key);

  String _getCalculatorRoute(String calculatorId) {
    switch (calculatorId) {
      case 'emi':
        return '/calculator/emi';
      case 'loan_amount':
        return '/calculator/loan_amount';
      case 'loan_term':
        return '/calculator/loan_term';
      case 'interest_rate':
        return '/calculator/interest_rate';
      case 'home_loan_eligibility':
        return '/calculator/home_loan_eligibility';
      case 'personal_loan_eligibility':
        return '/calculator/personal_loan_eligibility';
      case 'credit_card_emi':
        return '/calculator/credit_card_emi';
      case 'fd':
        return '/calculator/fd';
      case 'rd':
        return '/calculator/rd';
      case 'savings':
        return '/calculator/savings';
      case 'ppf':
        return '/calculator/ppf';
      case 'sip':
        return '/calculator/sip';
      case 'swp':
        return '/calculator/swp';
      case 'lumpsum':
        return '/calculator/lumpsum';
      case 'cagr':
        return '/calculator/cagr';
      case 'stock_return':
        return '/calculator/stock_return';
      case 'dividend_yield':
        return '/calculator/dividend_yield';
      case 'nps':
        return '/calculator/nps';
      case 'epf':
        return '/calculator/epf';
      case 'income_tax':
        return '/calculator/income_tax';
      case 'gst':
        return '/calculator/gst';
      case 'retirement':
      case 'retirement_planner':
        return '/calculator/retirement';
      case 'goal':
      case 'goal_planner':
        return '/calculator/goal';
      case 'education':
      case 'education_planner':
        return '/calculator/education';
      case 'inflation':
        return '/calculator/inflation';
      case 'sukanya':
      case 'sukanya_samriddhi':
        return '/calculator/sukanya';
      case 'simple_interest':
        return '/calculator/simple_interest';
      case 'compound_interest':
        return '/calculator/compound_interest';
      default:
        return '/calculators';
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Calculation?'),
        content: const Text(
          'Are you sure you want to remove this calculation from history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await di.sl<CalculationHistoryRepository>().deleteEntry(entry.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Calculation deleted from history'),
                    duration: Duration(seconds: 2),
                  ),
                );
                context.pop();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: entry.calculatorName,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export PDF',
            onPressed: () {
              CalculatorShareHelper.exportPdf(
                context: context,
                title: entry.calculatorName,
                inputs: entry.inputs,
                results: entry.results,
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share',
            onPressed: () {
              CalculatorShareHelper.shareText(
                context: context,
                title: entry.calculatorName,
                inputs: entry.inputs,
                results: entry.results,
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: Responsive.screenPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC9A96E).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          entry.icon,
                          color: const Color(0xFFC9A96E),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.calculatorName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    entry.formattedDateTime,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Primary Result Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E2340), Color(0xFF151828)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC9A96E).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        entry.primaryResultLabel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC9A96E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.primaryResultValue,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Calculated Results Breakdown
                const Text(
                  'CALCULATED RESULTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFFC9A96E),
                  ),
                ),
                const SizedBox(height: 8),
                GlassmorphicCard(
                  child: Column(
                    children: entry.results.entries.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.key,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textTheme.bodyMedium?.color ?? Colors.grey,
                              ),
                            ),
                            Text(
                              item.value,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Calculation Inputs Breakdown
                const Text(
                  'CALCULATION INPUTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFFC9A96E),
                  ),
                ),
                const SizedBox(height: 8),
                GlassmorphicCard(
                  child: Column(
                    children: entry.inputs.entries.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.key,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textTheme.bodyMedium?.color ?? Colors.grey,
                              ),
                            ),
                            Text(
                              item.value,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // Action: Open in Calculator
                GradientButton(
                  key: const ValueKey('history_open_in_calculator_button'),
                  text: 'Open in Calculator',
                  onPressed: () {
                    final route = _getCalculatorRoute(entry.calculatorId);
                    context.push(route);
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
