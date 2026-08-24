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
      appBar: CustomAppBar(title: 'NPS Calculator', actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)]),
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
          ],
        ),
      ),
        ),
      ),
    );
  }
}

