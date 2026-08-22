import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

class PpfCalculatorScreen extends StatefulWidget {
  const PpfCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<PpfCalculatorScreen> createState() => _PpfCalculatorScreenState();
}

class _PpfCalculatorScreenState extends State<PpfCalculatorScreen> with SingleTickerProviderStateMixin {
  double _yearlyInvestment = 150000;
  double _periodYears = 15;
  final double _interestRate = 7.1;

  double _totalInvestment = 0;
  double _totalInterest = 0;
  double _maturityValue = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculatePpf();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculatePpf() {
    final result = FinancialMath.calculatePPF(
      yearlyDeposit: _yearlyInvestment,
      annualRate: _interestRate,
      years: _periodYears.toInt(),
    );
    _maturityValue = result['maturityValue']!;
    _totalInvestment = result['totalDeposit']!;
    _totalInterest = result['totalInterest']!;
    _animationController.forward(from: 0.0);
    setState(() {});
  }

  void _shareResult(BuildContext context) {
    final text = 'FeroCalc PPF Calculator\n\nYearly Investment: \u20B9${_yearlyInvestment.toStringAsFixed(0)}\nRate: ${_interestRate}% p.a.\nPeriod: ${_periodYears.toStringAsFixed(0)} Years\nMaturity Value: \u20B9${_maturityValue.toStringAsFixed(0)}\nTotal Investment: \u20B9${_totalInvestment.toStringAsFixed(0)}\nTotal Interest: \u20B9${_totalInterest.toStringAsFixed(0)}\n\nDownload FeroCalc for more!';
    Share.share(text);
  }

  void _exportPdf(BuildContext context) {
    final text = 'FeroCalc PPF Report\n\nYearly Investment: \u20B9${_yearlyInvestment.toStringAsFixed(0)}\nRate: ${_interestRate}% p.a.\nPeriod: ${_periodYears.toStringAsFixed(0)} Years\nMaturity Value: \u20B9${_maturityValue.toStringAsFixed(0)}\nTotal Investment: \u20B9${_totalInvestment.toStringAsFixed(0)}\nTotal Interest: \u20B9${_totalInterest.toStringAsFixed(0)}';
    Share.share(text, subject: 'FeroCalc - PPF Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'PPF Calculator',
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
                        label: 'Yearly Investment',
                        value: _yearlyInvestment,
                        min: 500,
                        max: 150000,
                        prefix: '\u20B9',
                        onChanged: (val) {
                          setState(() => _yearlyInvestment = val);
                          _calculatePpf();
                        },
                      ),
                      const SizedBox(height: 16),
                      InputSliderField(
                        label: 'Time Period',
                        value: _periodYears,
                        min: 15,
                        max: 50,
                        suffix: ' Yrs',
                        onChanged: (val) {
                          setState(() => _periodYears = val);
                          _calculatePpf();
                        },
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Current Rate: $_interestRate% p.a.',
                          style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                        ),
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
                      SubResult(label: 'Total Investment', value: _currencyFormat.format(_totalInvestment)),
                      SubResult(label: 'Total Interest', value: _currencyFormat.format(_totalInterest)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildChart(context),
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Export Schedule',
                  onPressed: () => _exportPdf(context),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Text(
                    'Disclaimer: PPF interest rate is set by the Government of India and may change quarterly. Verify current rate with official sources.',
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
                    value: _totalInvestment,
                    title: '${(_totalInvestment / _maturityValue * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF1A5276),
                    radius: 60,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: _totalInterest,
                    title: '${(_totalInterest / _maturityValue * 100).toStringAsFixed(1)}%',
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
              _legendItem('Total Investment', const Color(0xFF1A5276)),
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
