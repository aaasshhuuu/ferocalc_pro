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

class NpsCalculatorScreen extends StatefulWidget {
  const NpsCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<NpsCalculatorScreen> createState() => _NpsCalculatorScreenState();
}

class _NpsCalculatorScreenState extends State<NpsCalculatorScreen> {
  double _monthlyInvestment = 5000;
  double _expectedReturn = 10.0;
  double _age = 30;
  final double _retirementAge = 60;
  double _annuityRate = 6.0;

  double _totalInvestment = 0;
  double _maturityAmount = 0;
  double _lumpsum = 0;
  double _monthlyPension = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateNps();
  }

  void _calculateNps() {
    final result = FinancialMath.calculateNPS(
      monthlyInvestment: _monthlyInvestment,
      expectedReturn: _expectedReturn,
      currentAge: _age.toInt(),
      retirementAge: _retirementAge.toInt(),
    );
    _totalInvestment = result['totalInvestment']!;
    _maturityAmount = result['maturityValue']!;
    _lumpsum = result['lumpSum']!;
    _monthlyPension = (result['annuityCorpus']! * (_annuityRate / 100)) / 12;
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateNps();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'nps',
      calculatorName: 'NPS Calculator',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Expected Monthly Pension',
      primaryResultValue: _currencyFormat.format(_monthlyPension),
      category: 'Investments',
    );
  }


  Map<String, String> _getInputs() => {
    'Monthly Contribution': _currencyFormat.format(_monthlyInvestment),
    'Expected Return Rate': '${_expectedReturn.toStringAsFixed(1)}% p.a.',
    'Current Age': '${_age.toInt()} Years',
    'Retirement Age': '${_retirementAge.toInt()} Years',
    'Expected Annuity Rate': '${_annuityRate.toStringAsFixed(1)}%',
  };

  Map<String, String> _getResults() => {
    'Total Maturity Corpus': _currencyFormat.format(_maturityAmount),
    'Total Investment': _currencyFormat.format(_totalInvestment),
    'Lump Sum Amount (60%)': _currencyFormat.format(_lumpsum),
    'Expected Monthly Pension': _currencyFormat.format(_monthlyPension),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'NPS Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'NPS Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'NPS Calculator',
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
                    label: 'Monthly Investment', value: _monthlyInvestment, min: 500, max: 150000, prefix: '₹',
                    onChanged: (val) { setState(() => _monthlyInvestment = val); _calculateNps(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Your Current Age', value: _age, min: 18, max: 59, suffix: ' Yrs',
                    onChanged: (val) { setState(() => _age = val); _calculateNps(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Expected Return', value: _expectedReturn, min: 8, max: 15, suffix: '%',
                    onChanged: (val) { setState(() => _expectedReturn = val); _calculateNps(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Expected Annuity Rate', value: _annuityRate, min: 4, max: 10, suffix: '%',
                    onChanged: (val) { setState(() => _annuityRate = val); _calculateNps(); },
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
              mainLabel: 'Expected Monthly Pension',
              mainValue: _currencyFormat.format(_monthlyPension),
              subResults: [
                SubResult(label: 'Total Corpus Generated', value: _currencyFormat.format(_maturityAmount)),
                SubResult(label: 'Tax-Free Lumpsum (60%)', value: _currencyFormat.format(_lumpsum)),
                SubResult(label: 'Total Investment', value: _currencyFormat.format(_totalInvestment)),
              ],
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'nps'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

