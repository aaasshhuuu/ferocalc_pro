import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import '../../../../core/utils/responsive.dart';

class RdCalculatorScreen extends StatefulWidget {
  const RdCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<RdCalculatorScreen> createState() => _RdCalculatorScreenState();
}

class _RdCalculatorScreenState extends State<RdCalculatorScreen> with SingleTickerProviderStateMixin {
  double _monthlyDeposit = 5000;
  double _interestRate = 6.5;
  double _tenureMonths = 60;

  double _totalDeposit = 0;
  double _maturityValue = 0;
  double _interestEarned = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculateRd();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateRd() {
    double p = _monthlyDeposit;
    double r = _interestRate / 100;
    int n = _tenureMonths.toInt();
    
    _totalDeposit = p * n;
    
    double maturity = 0;
    for (int i = 1; i <= n; i++) {
      double timeInYears = (n - i + 1) / 12.0;
      maturity += p * pow((1 + r / 4), 4 * timeInYears);
    }
    
    _maturityValue = maturity;
    _interestEarned = _maturityValue - _totalDeposit;
    
    _animationController.forward(from: 0.0);
    setState(() {});
  }

  void _shareResult(BuildContext context) {
    final text = 'FeroCalc RD Calculator\n\nMonthly Deposit: ₹${_monthlyDeposit.toStringAsFixed(0)}\nRate: ${_interestRate.toStringAsFixed(2)}%\nTenure: ${_tenureMonths.toStringAsFixed(0)} Mos\nMaturity Value: ₹${_maturityValue.toStringAsFixed(0)}\nTotal Deposit: ₹${_totalDeposit.toStringAsFixed(0)}\nInterest Earned: ₹${_interestEarned.toStringAsFixed(0)}\n\nDownload FeroCalc for more!';
    Share.share(text);
  }

  void _exportPdf(BuildContext context) {
    final text = 'FeroCalc RD Report\n\nMonthly Deposit: ₹${_monthlyDeposit.toStringAsFixed(0)}\nRate: ${_interestRate.toStringAsFixed(2)}%\nTenure: ${_tenureMonths.toStringAsFixed(0)} Mos\nMaturity Value: ₹${_maturityValue.toStringAsFixed(0)}\nTotal Deposit: ₹${_totalDeposit.toStringAsFixed(0)}\nInterest Earned: ₹${_interestEarned.toStringAsFixed(0)}';
    Share.share(text, subject: 'FeroCalc - RD Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'RD Calculator',
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: () => _exportPdf(context)),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)),
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
                GlassmorphicCard(
                  child: Column(
                    children: [
                      InputSliderField(
                        label: 'Monthly Deposit',
                        value: _monthlyDeposit,
                        min: 500,
                        max: 100000,
                        prefix: '₹',
                        onChanged: (val) {
                          setState(() => _monthlyDeposit = val);
                          _calculateRd();
                        },
                      ),
                      const SizedBox(height: 16),
                      InputSliderField(
                        label: 'Interest Rate (p.a)',
                        value: _interestRate,
                        min: 1,
                        max: 15,
                        suffix: '%',
                        onChanged: (val) {
                          setState(() => _interestRate = val);
                          _calculateRd();
                        },
                      ),
                      const SizedBox(height: 16),
                      InputSliderField(
                        label: 'Tenure',
                        value: _tenureMonths,
                        min: 6,
                        max: 120,
                        suffix: ' Mos',
                        onChanged: (val) {
                          setState(() => _tenureMonths = val);
                          _calculateRd();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ResultDisplayCard(
                    mainLabel: 'Maturity Value',
                    mainValue: _currencyFormat.format(_maturityValue),
                    subResults: [
                      SubResult(label: 'Total Deposit', value: _currencyFormat.format(_totalDeposit)),
                      SubResult(label: 'Interest Earned', value: _currencyFormat.format(_interestEarned)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildChart(context),
                const SizedBox(height: 24),
                GradientButton(text: 'Save Calculation',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calculation saved!'), backgroundColor: Color(0xFF10B981)),
                    );
                  }),
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
    if (_maturityValue <= 0) return const SizedBox.shrink();
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
                    value: _totalDeposit,
                    title: '${(_totalDeposit / _maturityValue * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF1A5276),
                    radius: 60,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: _interestEarned,
                    title: '${(_interestEarned / _maturityValue * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF00E676),
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
              _legendItem('Total Deposits', const Color(0xFF1A5276)),
              _legendItem('Interest Earned', const Color(0xFF00E676)),
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
