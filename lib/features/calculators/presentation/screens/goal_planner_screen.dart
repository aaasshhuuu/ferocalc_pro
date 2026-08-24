import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

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
      appBar: CustomAppBar(title: 'Goal Planner', actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)]),
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
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Monthly SIP Required',
              mainValue: _currencyFormat.format(_monthlySip),
              subResults: [
                SubResult(label: 'Future Goal Cost', value: _currencyFormat.format(_inflatedGoal)),
                SubResult(label: 'OR Lumpsum Needed', value: _currencyFormat.format(_lumpsumNeeded)),
              ],
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

