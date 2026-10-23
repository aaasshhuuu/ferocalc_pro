import 'package:flutter/material.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

import 'package:fincalc_pro/core/widgets/calculator_purpose_card.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import '../../../../core/utils/responsive.dart';
import 'package:fincalc_pro/features/history/presentation/helper/calculation_history_saver.dart';

class SavingsCalculatorScreen extends StatefulWidget {
  const SavingsCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<SavingsCalculatorScreen> createState() => _SavingsCalculatorScreenState();
}

class _SavingsCalculatorScreenState extends State<SavingsCalculatorScreen> {
  double _initialAmount = 10000;
  double _monthlySavings = 5000;
  double _interestRate = 5.0;
  double _periodYears = 5;

  double _totalSavings = 0;
  double _interestEarned = 0;
  double _finalAmount = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateSavings();
  }

  void _calculateSavings() {
    _totalSavings = FinancialMath.calculateSavings(
      initialAmount: _initialAmount,
      monthlyContribution: _monthlySavings,
      annualRate: _interestRate,
      months: (_periodYears * 12).toInt(),
    );
    
    // Original calculated finalAmount by separating initial fv and monthly fv, which is what calculateSavings does
    _finalAmount = _totalSavings; 
    _totalSavings = _initialAmount + (_monthlySavings * (_periodYears * 12).toInt());
    _interestEarned = _finalAmount - _totalSavings;
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateSavings();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'savings',
      calculatorName: 'Savings Calculator',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Final Amount',
      primaryResultValue: _currencyFormat.format(_finalAmount),
      category: 'Investments',
    );
  }


  Map<String, String> _getInputs() => {
    'Initial Deposit': _currencyFormat.format(_initialAmount),
    'Monthly Savings': _currencyFormat.format(_monthlySavings),
    'Interest Rate': '${_interestRate.toStringAsFixed(2)}% p.a.',
    'Tenure': '${_periodYears.toInt()} Years',
  };

  Map<String, String> _getResults() => {
    'Total Deposits': _currencyFormat.format(_totalSavings),
    'Interest Earned': _currencyFormat.format(_interestEarned),
    'Final Balance': _currencyFormat.format(_finalAmount),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Savings Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Savings Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Savings Calculator',
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
            padding: Responsive.screenPadding(context),
            child: Column(
          children: [
            GlassmorphicCard(
              child: Column(
                children: [
                  InputSliderField(
                    label: 'Initial Amount', value: _initialAmount, min: 0, max: 1000000, prefix: '₹',
                    onChanged: (val) { setState(() => _initialAmount = val); _calculateSavings(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Monthly Savings', value: _monthlySavings, min: 500, max: 500000, prefix: '₹',
                    onChanged: (val) { setState(() => _monthlySavings = val); _calculateSavings(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Interest Rate (p.a)', value: _interestRate, min: 1, max: 15, suffix: '%',
                    onChanged: (val) { setState(() => _interestRate = val); _calculateSavings(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Time Period', value: _periodYears, min: 1, max: 40, suffix: ' Yrs',
                    onChanged: (val) { setState(() => _periodYears = val); _calculateSavings(); },
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
            ResultDisplayCard(
              mainLabel: 'Final Amount',
              mainValue: _currencyFormat.format(_finalAmount),
              subResults: [
                SubResult(label: 'Total Savings', value: _currencyFormat.format(_totalSavings)),
                SubResult(label: 'Interest Earned', value: _currencyFormat.format(_interestEarned)),
              ],
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'savings'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

