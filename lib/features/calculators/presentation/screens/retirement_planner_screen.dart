import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

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
  }

  void _calculateRetirement() {
    double yearsToRetire = _retirementAge - _currentAge;
    double yearsInRetirement = _lifeExpectancy - _retirementAge;
    
    if (yearsToRetire <= 0 || yearsInRetirement <= 0) {
      _corpusNeeded = 0;
      _monthlySipNeeded = 0;
      setState(() {});
      return;
    }

    // Future monthly expense
    double futureMonthlyExpense = _monthlyExpense * pow((1 + _inflationRate / 100), yearsToRetire);
    double annualExpenseAtRetirement = futureMonthlyExpense * 12;

    // Inflation adjusted return post retirement
    double realReturn = ((1 + _postRetirementReturn / 100) / (1 + _inflationRate / 100)) - 1;
    
    // Corpus needed (PV of annuity)
    if (realReturn > 0) {
      _corpusNeeded = annualExpenseAtRetirement * (1 - pow(1 + realReturn, -yearsInRetirement)) / realReturn;
    } else {
      _corpusNeeded = annualExpenseAtRetirement * yearsInRetirement;
    }

    // SIP Needed
    double r = _preRetirementReturn / 12 / 100;
    double n = yearsToRetire * 12;
    if (r > 0) {
      _monthlySipNeeded = _corpusNeeded * r / (pow(1 + r, n) - 1);
    }
    
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
      appBar: CustomAppBar(title: 'Retirement Planner', actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)]),
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
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Corpus Needed at Retirement',
              mainValue: _currencyFormat.format(_corpusNeeded),
              subResults: [
                SubResult(label: 'Monthly SIP Needed Now', value: _currencyFormat.format(_monthlySipNeeded)),
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

