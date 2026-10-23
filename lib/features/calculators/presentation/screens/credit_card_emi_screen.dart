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

class CreditCardEmiScreen extends StatefulWidget {
  const CreditCardEmiScreen({Key? key}) : super(key: key);

  @override
  State<CreditCardEmiScreen> createState() => _CreditCardEmiScreenState();
}

class _CreditCardEmiScreenState extends State<CreditCardEmiScreen> {
  double _outstandingAmount = 50000;
  double _interestRate = 36.0;
  double _tenureMonths = 12;
  double _processingFeePercent = 1.0;

  double _emi = 0;
  double _totalInterest = 0;
  double _processingFeeAmount = 0;
  double _totalPayment = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateEmi();
  }

  void _calculateEmi() {
    final result = FinancialMath.calculateCreditCardEMI(
      outstanding: _outstandingAmount,
      annualRate: _interestRate,
      months: _tenureMonths.toInt(),
      processingFeePercent: _processingFeePercent,
    );
    _emi = result['emi']!;
    _totalInterest = result['totalInterest']!;
    _processingFeeAmount = result['processingFee']!;
    _totalPayment = result['totalPayment']! - _processingFeeAmount;
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateEmi();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'credit_card_emi',
      calculatorName: 'Credit Card EMI',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Monthly EMI',
      primaryResultValue: _currencyFormat.format(_emi),
      category: 'Loans',
    );
  }


  Map<String, String> _getInputs() => {
    'Outstanding Amount': _currencyFormat.format(_outstandingAmount),
    'Interest Rate': '${_interestRate.toStringAsFixed(2)}% p.a.',
    'Tenure': '${_tenureMonths.toInt()} Months',
    'Processing Fee': '${_processingFeePercent.toStringAsFixed(1)}%',
  };

  Map<String, String> _getResults() => {
    'Monthly EMI': _currencyFormat.format(_emi),
    'Total Interest': _currencyFormat.format(_totalInterest),
    'Processing Fee Amount': _currencyFormat.format(_processingFeeAmount),
    'Total Payment': _currencyFormat.format(_totalPayment + _processingFeeAmount),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Credit Card EMI',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Credit Card EMI',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Credit Card EMI',
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
                    label: 'Outstanding Amount', value: _outstandingAmount, min: 5000, max: 1000000, prefix: '₹',
                    onChanged: (val) { setState(() => _outstandingAmount = val); _calculateEmi(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Interest Rate (p.a)', value: _interestRate, min: 12, max: 48, suffix: '%',
                    onChanged: (val) { setState(() => _interestRate = val); _calculateEmi(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Tenure', value: _tenureMonths, min: 3, max: 48, suffix: ' Mos',
                    onChanged: (val) { setState(() => _tenureMonths = val); _calculateEmi(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Processing Fee (%)', value: _processingFeePercent, min: 0, max: 5, suffix: '%',
                    onChanged: (val) { setState(() => _processingFeePercent = val); _calculateEmi(); },
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
              mainLabel: 'Monthly EMI',
              mainValue: _currencyFormat.format(_emi),
              subResults: [
                SubResult(label: 'Processing Fee (1st month)', value: _currencyFormat.format(_processingFeeAmount)),
                SubResult(label: 'Total Interest Payable', value: _currencyFormat.format(_totalInterest)),
                SubResult(label: 'Total Payment', value: _currencyFormat.format(_totalPayment + _processingFeeAmount)),
              ],
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'credit_card_emi'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

