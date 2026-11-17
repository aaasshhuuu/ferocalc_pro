import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import '../../../../core/utils/financial_math.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/repositories/calculation_history_repository.dart';

class CalculationHistoryDetailScreen extends StatefulWidget {
  const CalculationHistoryDetailScreen({
    Key? key,
    required this.entry,
  }) : super(key: key);

  final CalculationHistoryEntry entry;

  @override
  State<CalculationHistoryDetailScreen> createState() =>
      _CalculationHistoryDetailScreenState();
}

class _CalculationHistoryDetailScreenState
    extends State<CalculationHistoryDetailScreen> {
  late CalculationHistoryEntry _entry;
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

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

  void _showRenameDialog() {
    final controller = TextEditingController(text: _entry.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Calculation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Calculation Name',
            hintText: 'e.g. Dream House Loan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final repo = di.sl<CalculationHistoryRepository>();
                await repo.renameEntry(_entry.id, newName);
                setState(() {
                  _entry = _entry.copyWith(
                    customName: newName,
                    updatedAt: DateTime.now(),
                  );
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Renamed to "$newName"')),
                  );
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFFC9A96E), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _duplicateCalculation() async {
    final repo = di.sl<CalculationHistoryRepository>();
    final duplicate = await repo.duplicateEntry(_entry.id);
    if (mounted && duplicate != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated "${_entry.title}"'),
          action: SnackBarAction(
            label: 'View',
            textColor: const Color(0xFFC9A96E),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CalculationHistoryDetailScreen(entry: duplicate),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _showEditInputsSheet() {
    final controllers = <String, TextEditingController>{};
    for (final e in _entry.inputs.entries) {
      // Remove symbols like ₹, %, Years for easier editing
      final raw = e.value.replaceAll(RegExp(r'[₹,%]'), '').trim();
      controllers[e.key] = TextEditingController(text: raw);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Inputs: ${_entry.title}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._entry.inputs.keys.map((key) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[key],
                    decoration: InputDecoration(
                      labelText: key,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                );
              }),
              const SizedBox(height: 16),
              GradientButton(
                text: 'Recalculate & Save',
                onPressed: () async {
                  final updatedInputs = <String, String>{};
                  final updatedRaw = <String, dynamic>{};

                  controllers.forEach((k, ctrl) {
                    final textVal = ctrl.text.trim();
                    updatedInputs[k] = textVal;
                    final numeric = double.tryParse(textVal.replaceAll(RegExp(r'[^\d.-]'), ''));
                    if (numeric != null) {
                      updatedRaw[k] = numeric;
                    }
                  });

                  // Recalculate results based on calculator type if possible
                  var updatedResults = Map<String, String>.from(_entry.results);
                  var primaryLabel = _entry.primaryResultLabel;
                  var primaryValue = _entry.primaryResultValue;

                  try {
                    if (_entry.calculatorId == 'emi') {
                      final amount = _findNum(updatedInputs, ['loan', 'amount', 'principal']) ?? 1000000;
                      final rate = _findNum(updatedInputs, ['rate', 'interest']) ?? 8.5;
                      final tenure = _findNum(updatedInputs, ['tenure', 'term', 'year']) ?? 10;
                      final tenureMonths = tenure <= 40 ? (tenure * 12).toInt() : tenure.toInt();
                      final emi = FinancialMath.calculateEMI(
                        principal: amount,
                        annualRate: rate,
                        months: tenureMonths,
                      );
                      final totalPayment = emi * tenureMonths;
                      final totalInterest = totalPayment - amount;
                      primaryLabel = 'Monthly EMI';
                      primaryValue = _currencyFormat.format(emi);
                      updatedResults = {
                        'Monthly EMI': primaryValue,
                        'Total Interest': _currencyFormat.format(totalInterest),
                        'Total Payment': _currencyFormat.format(totalPayment),
                      };
                    } else if (_entry.calculatorId == 'sip') {
                      final monthly = _findNum(updatedInputs, ['monthly', 'investment', 'sip']) ?? 5000;
                      final rate = _findNum(updatedInputs, ['rate', 'return', 'interest']) ?? 12.0;
                      final years = _findNum(updatedInputs, ['year', 'tenure', 'period']) ?? 10;
                      final months = (years * 12).toInt();
                      final maturity = FinancialMath.calculateSIPMaturity(
                        monthlyInvestment: monthly,
                        annualReturn: rate,
                        months: months,
                      );
                      final totalInv = monthly * months;
                      primaryLabel = 'Maturity Amount';
                      primaryValue = _currencyFormat.format(maturity);
                      updatedResults = {
                        'Total Investment': _currencyFormat.format(totalInv),
                        'Est. Returns': _currencyFormat.format(maturity - totalInv),
                        'Maturity Amount': primaryValue,
                      };
                    } else if (_entry.calculatorId == 'fd') {
                      final principal = _findNum(updatedInputs, ['principal', 'deposit', 'amount']) ?? 100000;
                      final rate = _findNum(updatedInputs, ['rate', 'interest']) ?? 6.5;
                      final years = _findNum(updatedInputs, ['year', 'tenure']) ?? 1.0;
                      final maturity = FinancialMath.calculateFDMaturity(
                        principal: principal,
                        annualRate: rate,
                        years: years,
                      );
                      primaryLabel = 'Maturity Amount';
                      primaryValue = _currencyFormat.format(maturity);
                      updatedResults = {
                        'Deposit Amount': _currencyFormat.format(principal),
                        'Total Interest': _currencyFormat.format(maturity - principal),
                        'Maturity Amount': primaryValue,
                      };
                    }
                  } catch (e) {
                    debugPrint('Recalculation fallback: $e');
                  }

                  final updatedEntry = _entry.copyWith(
                    inputs: updatedInputs,
                    results: updatedResults,
                    primaryResultLabel: primaryLabel,
                    primaryResultValue: primaryValue,
                    rawInputs: updatedRaw,
                    updatedAt: DateTime.now(),
                  );

                  final repo = di.sl<CalculationHistoryRepository>();
                  await repo.updateEntry(updatedEntry);

                  setState(() {
                    _entry = updatedEntry;
                  });

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calculation updated & recalculated')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _findNum(Map<String, String> map, List<String> matchKeywords) {
    for (final entry in map.entries) {
      final keyLower = entry.key.toLowerCase();
      if (matchKeywords.any((k) => keyLower.contains(k))) {
        final clean = entry.value.replaceAll(RegExp(r'[^\d.-]'), '');
        final val = double.tryParse(clean);
        if (val != null) return val;
      }
    }
    return null;
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
              await di.sl<CalculationHistoryRepository>().deleteEntry(_entry.id);
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
    final isUpdated = _entry.updatedAt != null &&
        _entry.updatedAt!.difference(_entry.timestamp).inSeconds.abs() > 2;

    return Scaffold(
      appBar: CustomAppBar(
        title: _entry.title,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: 'Rename',
            onPressed: _showRenameDialog,
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, color: Colors.white),
            tooltip: 'Duplicate',
            onPressed: _duplicateCalculation,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export PDF',
            onPressed: () {
              CalculatorShareHelper.exportPdf(
                context: context,
                title: _entry.title,
                inputs: _entry.inputs,
                results: _entry.results,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share',
            onPressed: () {
              CalculatorShareHelper.shareText(
                context: context,
                title: _entry.title,
                inputs: _entry.inputs,
                results: _entry.results,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
          const SizedBox(width: 8),
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
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC9A96E).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _entry.icon,
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
                              _entry.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_entry.calculatorName}${_entry.category != null ? ' • ${_entry.category}' : ''}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFC9A96E),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 13,
                                  color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    isUpdated
                                        ? 'Updated ${_entry.formattedUpdatedDateTime} (Saved ${_entry.formattedDateTime})'
                                        : 'Saved ${_entry.formattedDateTime}',
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
                    border: Border.all(color: const Color(0xFFC9A96E).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _entry.primaryResultLabel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC9A96E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _entry.primaryResultValue,
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
                    children: _entry.results.entries.map((item) {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CALCULATION INPUTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFFC9A96E),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.tune, size: 16, color: Color(0xFFC9A96E)),
                      label: const Text(
                        'Edit Inputs',
                        style: TextStyle(fontSize: 12, color: Color(0xFFC9A96E)),
                      ),
                      onPressed: _showEditInputsSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                GlassmorphicCard(
                  child: Column(
                    children: _entry.inputs.entries.map((item) {
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

                // Action Buttons
                GradientButton(
                  key: const ValueKey('history_open_in_calculator_button'),
                  text: 'Open in Calculator',
                  onPressed: () {
                    final route = _getCalculatorRoute(_entry.calculatorId);
                    context.push(route, extra: _entry);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('Edit & Recalculate Inputs'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC9A96E),
                    side: const BorderSide(color: Color(0xFFC9A96E)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showEditInputsSheet,
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
