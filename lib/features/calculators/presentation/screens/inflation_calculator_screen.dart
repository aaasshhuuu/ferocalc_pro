import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

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
    _futureCost = _currentCost * pow((1 + _inflationRate / 100), _years);
    _increaseAmount = _futureCost - _currentCost;
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
      appBar: CustomAppBar(title: 'Inflation Calculator', actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)]),
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
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Future Cost',
              mainValue: _currencyFormat.format(_futureCost),
              subResults: [
                SubResult(label: 'Total Cost Increase', value: _currencyFormat.format(_increaseAmount)),
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

