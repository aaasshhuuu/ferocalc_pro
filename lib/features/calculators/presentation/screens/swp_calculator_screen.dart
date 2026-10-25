import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/core/widgets/calculator_purpose_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/calculator_share_helper.dart';
import '../../../../core/utils/responsive.dart';
import 'package:fincalc_pro/features/history/presentation/helper/calculation_history_saver.dart';

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

  void _calculateAndSave() {
    _calculateSwp();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'swp',
      calculatorName: 'SWP Calculator',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Final Value',
      primaryResultValue: _currencyFormat.format(_finalValue),
      category: 'Investments',
    );
  }


  Map<String, String> _getInputs() => {
    'Total Investment': _currencyFormat.format(_totalInvestment),
    'Monthly Withdrawal': _currencyFormat.format(_withdrawalAmount),
    'Expected Return Rate': '${_expectedReturn.toStringAsFixed(2)}% p.a.',
    'Time Period': '${_periodYears.toInt()} Years',
  };

  Map<String, String> _getResults() => {
    'Total Withdrawn': _currencyFormat.format(_totalWithdrawal),
    'Final Value': _currencyFormat.format(_finalValue),
    'Total Earnings': _currencyFormat.format(_totalEarnings),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'SWP Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'SWP Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'SWP Calculator',
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () => _exportPdf(context),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareResult(context),
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
            GradientButton(
              text: 'Save Calculation',
              onPressed: _calculateAndSave,
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'swp'),
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

