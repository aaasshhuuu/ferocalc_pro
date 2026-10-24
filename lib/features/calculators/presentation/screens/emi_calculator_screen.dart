import 'package:flutter/material.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import 'amortization_schedule_screen.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/core/utils/formatters.dart';
import 'package:fincalc_pro/core/widgets/calculator_purpose_card.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/chart_widgets.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/features/history/presentation/helper/calculation_history_saver.dart';
import 'package:fincalc_pro/config/themes/app_colors.dart';
import 'package:fincalc_pro/config/themes/app_gradients.dart';
import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import '../../../../core/utils/responsive.dart';

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> with SingleTickerProviderStateMixin {
  double _loanAmount = 1000000;
  double _interestRate = 8.5;
  double _tenure = 10;
  bool _isMonths = false;
  bool _isFlatRate = false;

  double _emi = 0;
  double _totalInterest = 0;
  double _totalPayment = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculateEmi();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateEmi() {
    final int months = (_isMonths ? _tenure : _tenure * 12).toInt();
    if (_isFlatRate) {
      _emi = FinancialMath.calculateFlatRateEMI(
        principal: _loanAmount,
        annualRate: _interestRate,
        months: months,
      );
      final double tYears = months / 12.0;
      _totalInterest = FinancialMath.calculateSimpleInterest(
        principal: _loanAmount,
        annualRate: _interestRate,
        time: tYears,
        timeUnit: TimeUnit.years,
      );
      _totalPayment = _loanAmount + _totalInterest;
    } else {
      _emi = FinancialMath.calculateEMI(
        principal: _loanAmount,
        annualRate: _interestRate,
        months: months,
      );
      _totalPayment = _emi * months;
      _totalInterest = _totalPayment - _loanAmount;
    }
    _animationController.forward(from: 0.0);
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateEmi();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'emi',
      calculatorName: 'EMI Calculator',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Monthly EMI',
      primaryResultValue: _currencyFormat.format(_emi),
      category: 'Loans',
      rawInputs: {
        'loanAmount': _loanAmount,
        'interestRate': _interestRate,
        'tenure': _tenure,
        'isMonths': _isMonths,
        'isFlatRate': _isFlatRate,
      },
    );
  }

  Map<String, String> _getInputs() => {
    'Loan Amount': _currencyFormat.format(_loanAmount),
    'Interest Rate': '${_interestRate.toStringAsFixed(2)}% p.a.',
    'Tenure': '${_tenure.toStringAsFixed(0)} ${_isMonths ? 'months' : 'years'}',
    'Interest Scheme': _isFlatRate ? 'Flat Rate' : 'Reducing Balance',
  };

  Map<String, String> _getResults() => {
    'Monthly EMI': _currencyFormat.format(_emi),
    'Total Interest': _currencyFormat.format(_totalInterest),
    'Total Payment': _currencyFormat.format(_totalPayment),
    'Calculation Method': _isFlatRate ? 'Flat Rate' : 'Reducing Balance',
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'EMI Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'EMI Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _openAmortizationSchedule(BuildContext context) {
    final int months = (_isMonths ? _tenure : _tenure * 12).toInt();
    final args = {
      'loanAmount': _loanAmount,
      'interestRate': _interestRate,
      'tenureMonths': months,
      'isFlatRate': _isFlatRate,
    };
    try {
      context.push('/amortization-schedule', extra: args);
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AmortizationScheduleScreen(
            loanAmount: _loanAmount,
            interestRate: _interestRate,
            tenureMonths: months,
            isFlatRate: _isFlatRate,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'EMI Calculator',
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: () => _exportPdf(context)),
          SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)),
          SizedBox(width: 16),
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
            GlassmorphicCard(
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text('Interest Method', style: AppTextStyles.bodyText),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            key: const ValueKey('emi_method_reducing'),
                            label: const Text('Reducing Balance'),
                            selected: !_isFlatRate,
                            onSelected: (val) {
                              setState(() => _isFlatRate = false);
                              _calculateEmi();
                            },
                          ),
                          ChoiceChip(
                            key: const ValueKey('emi_method_flat'),
                            label: const Text('Flat Rate'),
                            selected: _isFlatRate,
                            onSelected: (val) {
                              setState(() => _isFlatRate = true);
                              _calculateEmi();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isFlatRate
                          ? 'Flat-rate interest calculated on the original principal.'
                          : 'Reducing-balance loan interest calculated on the outstanding balance.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Loan Amount',
                    value: _loanAmount,
                    min: 100000,
                    max: 50000000,
                    prefix: '₹',
                    onChanged: (val) {
                      setState(() => _loanAmount = val);
                      _calculateEmi();
                    },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Interest Rate (p.a)',
                    value: _interestRate,
                    min: 1,
                    max: 30,
                    suffix: '%',
                    onChanged: (val) {
                      setState(() => _interestRate = val);
                      _calculateEmi();
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text('Tenure in', style: AppTextStyles.bodyText),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Years'),
                            selected: !_isMonths,
                            onSelected: (val) {
                              setState(() {
                                _isMonths = false;
                                _tenure = (_tenure / 12).clamp(1, 30);
                              });
                              _calculateEmi();
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Months'),
                            selected: _isMonths,
                            onSelected: (val) {
                              setState(() {
                                _isMonths = true;
                                _tenure = (_tenure * 12).clamp(1, 360);
                              });
                              _calculateEmi();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InputSliderField(
                    label: 'Tenure',
                    value: _tenure,
                    min: 1,
                    max: _isMonths ? 360 : 30,
                    suffix: _isMonths ? ' mo' : ' yr',
                    onChanged: (val) {
                      setState(() => _tenure = val);
                      _calculateEmi();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              key: const ValueKey('calculate_button'),
              text: 'Calculate',
              onPressed: _calculateAndSave,
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fadeAnimation,
              child: ResultDisplayCard(
                mainLabel: 'Monthly EMI',
                mainValue: _currencyFormat.format(_emi),
                subResults: [
                  SubResult(label: 'Principal Amount', value: _currencyFormat.format(_loanAmount)),
                  SubResult(label: 'Total Interest', value: _currencyFormat.format(_totalInterest)),
                  SubResult(label: 'Total Payment', value: _currencyFormat.format(_totalPayment)),
                  SubResult(label: 'Calculation Method', value: _isFlatRate ? 'Flat Rate' : 'Reducing Balance'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildChart(context),
            const SizedBox(height: 24),

            GradientButton(
              key: const ValueKey('view_amortization_schedule_button'),
              text: 'View Amortization Schedule',
              onPressed: () => _openAmortizationSchedule(context),
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'emi'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Text(
                'Disclaimer: Results are for informational purposes only. Not financial advice.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    // Only show if calculated
    if (_totalPayment <= 0) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          Text('Breakdown', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          )),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: _loanAmount,
                    title: '${(_loanAmount / _totalPayment * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF1A5276),
                    radius: 60,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: _totalInterest,
                    title: '${(_totalInterest / _totalPayment * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFFC9A96E),
                    radius: 60,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _legendItem('Principal', const Color(0xFF1A5276)),
              _legendItem('Interest', const Color(0xFFC9A96E)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
      ],
    );
  }

}
