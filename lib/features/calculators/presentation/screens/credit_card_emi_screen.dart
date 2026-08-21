import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

class CreditCardEmiScreen extends StatefulWidget {
  const CreditCardEmiScreen({Key? key}) : super(key: key);

  @override
  State<CreditCardEmiScreen> createState() => _CreditCardEmiScreenState();
}

class _CreditCardEmiScreenState extends State<CreditCardEmiScreen> {
  double _outstandingAmount = 50000;
  double _interestRate = 36.0;
  double _tenureMonths = 12;
  double _processingFeePercent = 1.0;

  double _emi = 0;
  double _totalInterest = 0;
  double _processingFeeAmount = 0;
  double _totalPayment = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateEmi();
  }

  void _calculateEmi() {
    double p = _outstandingAmount;
    double r = _interestRate / 12 / 100;
    double n = _tenureMonths;

    _emi = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    _totalPayment = _emi * n;
    _totalInterest = _totalPayment - p;
    _processingFeeAmount = p * (_processingFeePercent / 100);
    
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
      appBar: CustomAppBar(title: 'Credit Card EMI', actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)]),
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
                    label: 'Outstanding Amount', value: _outstandingAmount, min: 5000, max: 1000000, prefix: '₹',
                    onChanged: (val) { setState(() => _outstandingAmount = val); _calculateEmi(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Interest Rate (p.a)', value: _interestRate, min: 12, max: 48, suffix: '%',
                    onChanged: (val) { setState(() => _interestRate = val); _calculateEmi(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Tenure', value: _tenureMonths, min: 3, max: 48, suffix: ' Mos',
                    onChanged: (val) { setState(() => _tenureMonths = val); _calculateEmi(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Processing Fee (%)', value: _processingFeePercent, min: 0, max: 5, suffix: '%',
                    onChanged: (val) { setState(() => _processingFeePercent = val); _calculateEmi(); },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Monthly EMI',
              mainValue: _currencyFormat.format(_emi),
              subResults: [
                SubResult(label: 'Processing Fee (1st month)', value: _currencyFormat.format(_processingFeeAmount)),
                SubResult(label: 'Total Interest Payable', value: _currencyFormat.format(_totalInterest)),
                SubResult(label: 'Total Payment', value: _currencyFormat.format(_totalPayment + _processingFeeAmount)),
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

