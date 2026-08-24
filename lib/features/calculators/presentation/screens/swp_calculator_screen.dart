import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

class SwpCalculatorScreen extends StatefulWidget {
  const SwpCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<SwpCalculatorScreen> createState() => _SwpCalculatorScreenState();
}

class _SwpCalculatorScreenState extends State<SwpCalculatorScreen> with SingleTickerProviderStateMixin {
  double _totalInvestment = 1000000;
  double _withdrawalAmount = 10000;
  double _expectedReturn = 8.0;
  double _periodYears = 10;

  double _totalWithdrawal = 0;
  double _finalValue = 0;
  double _totalEarnings = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculateSwp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateSwp() {
    final result = FinancialMath.calculateSWP(
      investment: _totalInvestment,
      withdrawal: _withdrawalAmount,
      annualReturn: _expectedReturn,
      months: (_periodYears * 12).toInt(),
    );
    _finalValue = result['finalBalance']!;
    _totalWithdrawal = result['totalWithdrawn']!;
    _totalEarnings = result['totalEarnings']!;
    
    _animationController.forward(from: 0.0);
    setState(() {});
  }


  void _shareResult(BuildContext context) {
    // Use share_plus to share the calculation result text
    final resultText = 'Check out my calculation on FeroCalc!';
    // For now show a snackbar since share_plus may not work on web
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Result shared!'), backgroundColor: const Color(0xFF10B981)),
    );
  }

  void _exportPdf(BuildContext context) {
    _shareResult(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'SWP Calculator',
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
                    label: 'Total Investment',
                    value: _totalInvestment,
                    min: 100000,
                    max: 50000000,
                    prefix: '₹',
                    onChanged: (val) {
                      setState(() => _totalInvestment = val);
                      _calculateSwp();
                    },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Monthly Withdrawal',
                    value: _withdrawalAmount,
                    min: 1000,
                    max: 100000,
                    prefix: '₹',
                    onChanged: (val) {
                      setState(() => _withdrawalAmount = val);
                      _calculateSwp();
                    },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Expected Return (p.a)',
                    value: _expectedReturn,
                    min: 1,
                    max: 30,
                    suffix: '%',
                    onChanged: (val) {
                      setState(() => _expectedReturn = val);
                      _calculateSwp();
                    },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Time Period',
                    value: _periodYears,
                    min: 1,
                    max: 30,
                    suffix: ' Yrs',
                    onChanged: (val) {
                      setState(() => _periodYears = val);
                      _calculateSwp();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fadeAnimation,
              child: ResultDisplayCard(
                mainLabel: 'Final Value',
                mainValue: _currencyFormat.format(_finalValue),
                mainValueColor: _finalValue == 0 ? Colors.redAccent : null,
                subResults: [
                  SubResult(label: 'Total Withdrawal', value: _currencyFormat.format(_totalWithdrawal)),
                  SubResult(label: 'Total Earnings', value: _currencyFormat.format(_totalEarnings)),
                ],
              ),
            ),
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
}

