import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:intl/intl.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

class LumpsumCalculatorScreen extends StatefulWidget {
  const LumpsumCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<LumpsumCalculatorScreen> createState() => _LumpsumCalculatorScreenState();
}

class _LumpsumCalculatorScreenState extends State<LumpsumCalculatorScreen> with SingleTickerProviderStateMixin {
  double _investmentAmount = 100000;
  double _expectedReturn = 12.0;
  double _periodYears = 10;

  double _totalValue = 0;
  double _estimatedReturns = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculateLumpsum();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateLumpsum() {
    _totalValue = FinancialMath.calculateLumpsum(
      principal: _investmentAmount,
      annualReturn: _expectedReturn,
      years: _periodYears,
    );
    _estimatedReturns = _totalValue - _investmentAmount;
    _animationController.forward(from: 0.0);
    setState(() {});
  }

  void _shareResult(BuildContext context) {
    final text = 'FeroCalc Lumpsum Calculator\n\nInvestment: \u20B9${_investmentAmount.toStringAsFixed(0)}\nExpected Return: ${_expectedReturn.toStringAsFixed(1)}%\nPeriod: ${_periodYears.toStringAsFixed(0)} Years\nTotal Value: \u20B9${_totalValue.toStringAsFixed(0)}\nEst. Returns: \u20B9${_estimatedReturns.toStringAsFixed(0)}\n\nDownload FeroCalc for more!';
    Share.share(text);
  }

  void _exportPdf(BuildContext context) {
    final text = 'FeroCalc Lumpsum Report\n\nInvestment: \u20B9${_investmentAmount.toStringAsFixed(0)}\nExpected Return: ${_expectedReturn.toStringAsFixed(1)}%\nPeriod: ${_periodYears.toStringAsFixed(0)} Years\nTotal Value: \u20B9${_totalValue.toStringAsFixed(0)}\nEst. Returns: \u20B9${_estimatedReturns.toStringAsFixed(0)}';
    Share.share(text, subject: 'FeroCalc - Lumpsum Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Lumpsum Calculator',
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
                        label: 'Total Investment',
                        value: _investmentAmount,
                        min: 5000,
                        max: 10000000,
                        prefix: '\u20B9',
                        onChanged: (val) {
                          setState(() => _investmentAmount = val);
                          _calculateLumpsum();
                        },
                      ),
                      const SizedBox(height: 16),
                      InputSliderField(
                        label: 'Expected Return Rate (p.a)',
                        value: _expectedReturn,
                        min: 1,
                        max: 30,
                        suffix: '%',
                        onChanged: (val) {
                          setState(() => _expectedReturn = val);
                          _calculateLumpsum();
                        },
                      ),
                      const SizedBox(height: 16),
                      InputSliderField(
                        label: 'Time Period',
                        value: _periodYears,
                        min: 1,
                        max: 40,
                        suffix: ' Yrs',
                        onChanged: (val) {
                          setState(() => _periodYears = val);
                          _calculateLumpsum();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ResultDisplayCard(
                    mainLabel: 'Total Value',
                    mainValue: _currencyFormat.format(_totalValue),
                    subResults: [
                      SubResult(label: 'Invested Amount', value: _currencyFormat.format(_investmentAmount)),
                      SubResult(label: 'Est. Returns', value: _currencyFormat.format(_estimatedReturns)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildChart(context),
                const SizedBox(height: 24),
                GradientButton(
                  text: 'Export PDF',
                  onPressed: () => _exportPdf(context),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Text(
                    'Disclaimer: Estimated returns are not guaranteed. Results are for informational purposes only.',
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
    if (_totalValue <= 0) return const SizedBox.shrink();
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
                    value: _investmentAmount,
                    title: '${(_investmentAmount / _totalValue * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF1A5276),
                    radius: 60,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: _estimatedReturns,
                    title: '${(_estimatedReturns / _totalValue * 100).toStringAsFixed(1)}%',
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
              _legendItem('Investment Amount', const Color(0xFF1A5276)),
              _legendItem('Returns', const Color(0xFF00E676)),
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
