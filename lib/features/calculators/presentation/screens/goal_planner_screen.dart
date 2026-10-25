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

class GoalPlannerScreen extends StatefulWidget {
  const GoalPlannerScreen({Key? key}) : super(key: key);

  @override
  State<GoalPlannerScreen> createState() => _GoalPlannerScreenState();
}

class _GoalPlannerScreenState extends State<GoalPlannerScreen> {
  final TextEditingController _goalNameCtrl = TextEditingController(text: 'Buy a House');
  double _currentCost = 5000000;
  double _years = 5;
  double _inflationRate = 6.0;
  double _expectedReturn = 12.0;

  double _inflatedGoal = 0;
  double _monthlySip = 0;
  double _lumpsumNeeded = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateGoal();
  }  void _calculateGoal() {
    final result = FinancialMath.calculateGoalPlanner(
      goalAmount: _currentCost,
      yearsToGoal: _years.toInt(),
      inflationRate: _inflationRate,
      expectedReturn: _expectedReturn,
    );

    _inflatedGoal = result['inflationAdjustedGoal'] ?? 0;
    _monthlySip = result['monthlySIPNeeded'] ?? 0;
    _lumpsumNeeded = result['lumpsumNeeded'] ?? 0;
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateGoal();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'goal_planner',
      calculatorName: 'Goal Planner',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Monthly SIP Required',
      primaryResultValue: _currencyFormat.format(_monthlySip),
      category: 'Planning',
    );
  }


  Map<String, String> _getInputs() => {
    'Goal Name': _goalNameCtrl.text,
    'Current Target Cost': _currencyFormat.format(_currentCost),
    'Time Horizon': '${_years.toInt()} Years',
    'Expected Inflation': '${_inflationRate.toStringAsFixed(1)}%',
    'Expected Return': '${_expectedReturn.toStringAsFixed(1)}%',
  };

  Map<String, String> _getResults() => {
    'Inflated Goal Amount': _currencyFormat.format(_inflatedGoal),
    'Monthly SIP Needed': _currencyFormat.format(_monthlySip),
    'Lumpsum Needed Today': _currencyFormat.format(_lumpsumNeeded),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Goal Planner',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Goal Planner',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Goal Planner',
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Goal Name', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _goalNameCtrl,
                    decoration: InputDecoration(
                      filled: true, fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Current Cost of Goal', value: _currentCost, min: 10000, max: 50000000, prefix: '₹',
                    onChanged: (val) { setState(() => _currentCost = val); _calculateGoal(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Years to Achieve', value: _years, min: 1, max: 40, suffix: ' Yrs',
                    onChanged: (val) { setState(() => _years = val); _calculateGoal(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Inflation Rate', value: _inflationRate, min: 1, max: 15, suffix: '%',
                    onChanged: (val) { setState(() => _inflationRate = val); _calculateGoal(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Expected Return', value: _expectedReturn, min: 1, max: 30, suffix: '%',
                    onChanged: (val) { setState(() => _expectedReturn = val); _calculateGoal(); },
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
                SubResult(label: 'Future Goal Cost', value: _currencyFormat.format(_inflatedGoal)),
                SubResult(label: 'OR Lumpsum Needed', value: _currencyFormat.format(_lumpsumNeeded)),
              ],
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'goal'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

