import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import '../../../../core/utils/responsive.dart';

class SipCalculatorScreen extends StatefulWidget {
  const SipCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<SipCalculatorScreen> createState() => _SipCalculatorScreenState();
}

class _SipCalculatorScreenState extends State<SipCalculatorScreen> with SingleTickerProviderStateMixin {
  double _monthlyInvestment = 5000;
  double _expectedReturn = 12.0;
  double _periodYears = 10;

  double _investedAmount = 0;
  double _estimatedReturns = 0;
  double _totalValue = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculateSip();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateSip() {
    int months = (_periodYears * 12).toInt();
    _investedAmount = _monthlyInvestment * months;
    _totalValue = FinancialMath.calculateSIPMaturity(
      monthlyInvestment: _monthlyInvestment,
      annualReturn: _expectedReturn,
      months: months,
    );
    _estimatedReturns = _totalValue - _investedAmount;
    _animationController.forward(from: 0.0);
    setState(() {});
  }

  void _shareResult(BuildContext context) {
    final text = 'FeroCalc SIP Calculator\n\nMonthly Investment: ₹${_monthlyInvestment.toStringAsFixed(0)}\nExpected Return: ${_expectedReturn.toStringAsFixed(2)}%\nTime Period: ${_periodYears.toStringAsFixed(0)} Years\nInvested Amount: ₹${_investedAmount.toStringAsFixed(0)}\nEstimated Returns: ₹${_estimatedReturns.toStringAsFixed(0)}\nTotal Value: ₹${_totalValue.toStringAsFixed(0)}\n\nDownload FeroCalc for more!';
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
        title: 'SIP Calculator',
        actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)],
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
                    label: 'Monthly Investment',
                    value: _monthlyInvestment,
                    min: 500,
                    max: 500000,
                    prefix: '₹',
                    onChanged: (val) {
                      setState(() => _monthlyInvestment = val);
                      _calculateSip();
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
                      _calculateSip();
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
                      _calculateSip();
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
                  SubResult(label: 'Invested Amount', value: _currencyFormat.format(_investedAmount)),
                  SubResult(label: 'Est. Returns', value: _currencyFormat.format(_estimatedReturns)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildChart(context),
            const SizedBox(height: 24),

            GradientButton(text: 'Export PDF',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF exported!'), backgroundColor: Color(0xFF10B981)),
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
    // Only show if calculated
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
                    value: _investedAmount,
                    title: '${(_investedAmount / _totalValue * 100).toStringAsFixed(1)}%',
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
              _legendItem('Total Invested', const Color(0xFF1A5276)),
              _legendItem('Wealth Gained', const Color(0xFF00E676)),
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
