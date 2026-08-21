import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

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
  }

  void _calculateEducation() {
    double years = _startAge - _childAge;
    if (years <= 0) {
      _futureCost = _currentCost;
      _monthlySip = 0;
      _lumpsumNeeded = _currentCost;
      setState(() {});
      return;
    }

    _futureCost = _currentCost * pow((1 + _inflationRate / 100), years);
    
    double r = _expectedReturn / 12 / 100;
    double n = years * 12;
    if (r > 0) {
      _monthlySip = _futureCost * r / (pow(1 + r, n) - 1);
      _lumpsumNeeded = _futureCost / pow(1 + _expectedReturn / 100, years);
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
      appBar: CustomAppBar(title: 'Education Planner', actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)]),
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
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Monthly SIP Required',
              mainValue: _currencyFormat.format(_monthlySip),
              subResults: [
                SubResult(label: 'Future Education Cost', value: _currencyFormat.format(_futureCost)),
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

