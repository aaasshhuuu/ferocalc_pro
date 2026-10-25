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

class RetirementPlannerScreen extends StatefulWidget {
  const RetirementPlannerScreen({Key? key}) : super(key: key);

  @override
  State<RetirementPlannerScreen> createState() => _RetirementPlannerScreenState();
}

class _RetirementPlannerScreenState extends State<RetirementPlannerScreen> {
  double _currentAge = 30;
  double _retirementAge = 60;
  double _lifeExpectancy = 85;
  double _monthlyExpense = 50000;
  double _inflationRate = 6.0;
  double _preRetirementReturn = 12.0;
  double _postRetirementReturn = 7.0;

  double _corpusNeeded = 0;
  double _monthlySipNeeded = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateRetirement();
  }  void _calculateRetirement() {
    if (_retirementAge <= _currentAge || _lifeExpectancy <= _retirementAge) {
      _corpusNeeded = 0;
      _monthlySipNeeded = 0;
      setState(() {});
      return;
    }

    final result = FinancialMath.calculateRetirementCorpus(
      currentAge: _currentAge.toInt(),
      retirementAge: _retirementAge.toInt(),
      monthlyExpense: _monthlyExpense,
      inflationRate: _inflationRate,
      preRetirementReturn: _preRetirementReturn,
      postRetirementReturn: _postRetirementReturn,
      lifeExpectancy: _lifeExpectancy.toInt(),
    );

    _corpusNeeded = result['corpusNeeded'] ?? 0;
    _monthlySipNeeded = result['monthlySIPNeeded'] ?? 0;
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateRetirement();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'retirement_planner',
      calculatorName: 'Retirement Planner',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Corpus Needed at Retirement',
      primaryResultValue: _currencyFormat.format(_corpusNeeded),
      category: 'Planning',
    );
  }


  Map<String, String> _getInputs() => {
    'Current Age': '${_currentAge.toInt()} Years',
    'Retirement Age': '${_retirementAge.toInt()} Years',
    'Life Expectancy': '${_lifeExpectancy.toInt()} Years',
    'Current Monthly Expense': _currencyFormat.format(_monthlyExpense),
    'Expected Inflation': '${_inflationRate.toStringAsFixed(1)}%',
    'Pre-retirement Return': '${_preRetirementReturn.toStringAsFixed(1)}%',
    'Post-retirement Return': '${_postRetirementReturn.toStringAsFixed(1)}%',
  };

  Map<String, String> _getResults() => {
    'Retirement Corpus Needed': _currencyFormat.format(_corpusNeeded),
    'Monthly SIP Needed': _currencyFormat.format(_monthlySipNeeded),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Retirement Planner',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Retirement Planner',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Retirement Planner',
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
                    label: 'Current Age', value: _currentAge, min: 20, max: 55, suffix: ' Yrs',
                    onChanged: (val) { setState(() => _currentAge = val); _calculateRetirement(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Retirement Age', value: _retirementAge, min: 40, max: 65, suffix: ' Yrs',
                    onChanged: (val) { setState(() => _retirementAge = val); _calculateRetirement(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Current Monthly Expenses', value: _monthlyExpense, min: 10000, max: 500000, prefix: '₹',
                    onChanged: (val) { setState(() => _monthlyExpense = val); _calculateRetirement(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Expected Inflation Rate', value: _inflationRate, min: 4, max: 12, suffix: '%',
                    onChanged: (val) { setState(() => _inflationRate = val); _calculateRetirement(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Pre-Retirement Return', value: _preRetirementReturn, min: 8, max: 15, suffix: '%',
                    onChanged: (val) { setState(() => _preRetirementReturn = val); _calculateRetirement(); },
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
              mainLabel: 'Corpus Needed at Retirement',
              mainValue: _currencyFormat.format(_corpusNeeded),
              subResults: [
                SubResult(label: 'Monthly SIP Needed Now', value: _currencyFormat.format(_monthlySipNeeded)),
              ],
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'retirement'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

