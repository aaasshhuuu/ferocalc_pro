import 'package:flutter/material.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/core/utils/formatters.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/chart_widgets.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
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
    double p = _loanAmount;
    double r = _interestRate / 12 / 100;
    double n = _isMonths ? _tenure : _tenure * 12;

    if (r == 0) {
      _emi = p / n;
    } else {
      _emi = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    }
    _totalPayment = _emi * n;
    _totalInterest = _totalPayment - p;
    
    _animationController.forward(from: 0.0);
    setState(() {});
  }


  void _shareResult(BuildContext context) {
    final text = 'FeroCalc EMI Calculator\n\nLoan: ₹${_loanAmount.toStringAsFixed(0)}\nRate: ${_interestRate.toStringAsFixed(2)}%\nTenure: ${_tenure.toStringAsFixed(0)} ${_isMonths ? 'months' : 'years'}\nEMI: ₹${_emi.toStringAsFixed(0)}\nTotal Interest: ₹${_totalInterest.toStringAsFixed(0)}\nTotal Payment: ₹${_totalPayment.toStringAsFixed(0)}\n\nDownload FeroCalc for more!';
    Share.share(text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Result shared!'), backgroundColor: Color(0xFF10B981)),
    );
  }

  void _exportPdf(BuildContext context) {
    _shareResult(context);
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tenure in', style: AppTextStyles.bodyText),
                      Row(
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
                          const SizedBox(width: 8),
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
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fadeAnimation,
              child: ResultDisplayCard(
                mainLabel: 'Monthly EMI',
                mainValue: _currencyFormat.format(_emi),
                subResults: [
                  SubResult(label: 'Principal Amount', value: _currencyFormat.format(_loanAmount)),
                  SubResult(label: 'Total Interest', value: _currencyFormat.format(_totalInterest)),
                  SubResult(label: 'Total Amount', value: _currencyFormat.format(_totalPayment)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildChart(context),
            const SizedBox(height: 24),

            GradientButton(
              text: 'View Amortization Schedule',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Amortization schedule coming soon!'), backgroundColor: Color(0xFF10B981)),
                );
              },
            ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
      ],
    );
  }

}

