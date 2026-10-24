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

class EducationPlannerScreen extends StatefulWidget {
  const EducationPlannerScreen({Key? key}) : super(key: key);

  @override
  State<EducationPlannerScreen> createState() => _EducationPlannerScreenState();
}

class _EducationPlannerScreenState extends State<EducationPlannerScreen> {
  double _childAge = 5;
  double _startAge = 18;
  double _currentCost = 1000000;
  double _inflationRate = 10.0;
  double _expectedReturn = 12.0;

  double _futureCost = 0;
  double _monthlySip = 0;
  double _lumpsumNeeded = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateEducation();
  }  void _calculateEducation() {
    if ((_startAge - _childAge) <= 0) {
      _futureCost = _currentCost;
      _monthlySip = 0;
      _lumpsumNeeded = _currentCost;
      setState(() {});
      return;
    }

    final result = FinancialMath.calculateEducationPlanner(
      childAge: _childAge.toInt(),
      educationStartAge: _startAge.toInt(),
      currentCost: _currentCost,
      educationInflation: _inflationRate,
      expectedReturn: _expectedReturn,
    );

    _futureCost = result['inflationAdjustedGoal'] ?? 0;
    _monthlySip = result['monthlySIPNeeded'] ?? 0;
    _lumpsumNeeded = result['lumpsumNeeded'] ?? 0;
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateEducation();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'education_planner',
      calculatorName: 'Education Planner',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Monthly SIP Required',
      primaryResultValue: _currencyFormat.format(_monthlySip),
      category: 'Planning',
    );
  }


  Map<String, String> _getInputs() => {
    'Current Child Age': '${_childAge.toInt()} Years',
    'College Start Age': '${_startAge.toInt()} Years',
    'Current Cost of Course': _currencyFormat.format(_currentCost),
    'Inflation Rate': '${_inflationRate.toStringAsFixed(1)}%',
    'Expected Return': '${_expectedReturn.toStringAsFixed(1)}%',
  };

  Map<String, String> _getResults() => {
    'Future Cost of Education': _currencyFormat.format(_futureCost),
    'Monthly SIP Needed': _currencyFormat.format(_monthlySip),
    'One-time Lumpsum Needed': _currencyFormat.format(_lumpsumNeeded),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Education Planner',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Education Planner',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Education Planner',
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
                    label: "Child's Current Age", value: _childAge, min: 0, max: 25, suffix: ' Yrs',
                    onChanged: (val) { setState(() => _childAge = val); _calculateEducation(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Education Start Age', value: _startAge, min: 10, max: 30, suffix: ' Yrs',
                    onChanged: (val) { setState(() => _startAge = val); _calculateEducation(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Current Cost of Education', value: _currentCost, min: 50000, max: 20000000, prefix: '₹',
                    onChanged: (val) { setState(() => _currentCost = val); _calculateEducation(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Education Inflation', value: _inflationRate, min: 5, max: 20, suffix: '%',
                    onChanged: (val) { setState(() => _inflationRate = val); _calculateEducation(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Expected Return', value: _expectedReturn, min: 1, max: 30, suffix: '%',
                    onChanged: (val) { setState(() => _expectedReturn = val); _calculateEducation(); },
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
              mainLabel: 'Monthly SIP Required',
              mainValue: _currencyFormat.format(_monthlySip),
              subResults: [
                SubResult(label: 'Future Education Cost', value: _currencyFormat.format(_futureCost)),
                SubResult(label: 'OR Lumpsum Needed', value: _currencyFormat.format(_lumpsumNeeded)),
              ],
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'education'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

