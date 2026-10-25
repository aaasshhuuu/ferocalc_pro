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

class InflationCalculatorScreen extends StatefulWidget {
  const InflationCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<InflationCalculatorScreen> createState() => _InflationCalculatorScreenState();
}

class _InflationCalculatorScreenState extends State<InflationCalculatorScreen> {
  double _currentCost = 100000;
  double _inflationRate = 6.0;
  double _years = 10;

  double _futureCost = 0;
  double _increaseAmount = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateInflation();
  }

  void _calculateInflation() {
    _futureCost = FinancialMath.calculateInflationAdjustedValue(
      presentValue: _currentCost,
      inflationRate: _inflationRate,
      years: _years,
    );
    _increaseAmount = _futureCost - _currentCost;
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateInflation();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'inflation',
      calculatorName: 'Inflation Calculator',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Future Cost',
      primaryResultValue: _currencyFormat.format(_futureCost),
      category: 'Planning',
    );
  }


  Map<String, String> _getInputs() => {
    'Current Cost': _currencyFormat.format(_currentCost),
    'Inflation Rate': '${_inflationRate.toStringAsFixed(1)}%',
    'Time Horizon': '${_years.toInt()} Years',
  };

  Map<String, String> _getResults() => {
    'Future Cost': _currencyFormat.format(_futureCost),
    'Increase in Cost': _currencyFormat.format(_increaseAmount),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Inflation Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Inflation Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Inflation Calculator',
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
                    label: 'Current Cost',
                    value: _currentCost,
                    min: 1000, max: 10000000, prefix: '₹',
                    onChanged: (val) { setState(() => _currentCost = val); _calculateInflation(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Expected Inflation Rate (p.a)',
                    value: _inflationRate,
                    min: 1, max: 15, suffix: '%',
                    onChanged: (val) { setState(() => _inflationRate = val); _calculateInflation(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Time Period',
                    value: _years,
                    min: 1, max: 50, suffix: ' Yrs',
                    onChanged: (val) { setState(() => _years = val); _calculateInflation(); },
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
              mainLabel: 'Future Cost',
              mainValue: _currencyFormat.format(_futureCost),
              subResults: [
                SubResult(label: 'Total Cost Increase', value: _currencyFormat.format(_increaseAmount)),
              ],
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'inflation'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

