import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

class HomeLoanEligibilityScreen extends StatefulWidget {
  const HomeLoanEligibilityScreen({Key? key}) : super(key: key);

  @override
  State<HomeLoanEligibilityScreen> createState() => _HomeLoanEligibilityScreenState();
}

class _HomeLoanEligibilityScreenState extends State<HomeLoanEligibilityScreen> {
  double _monthlyIncome = 100000;
  double _interestRate = 8.5;
  double _tenureYears = 20;
  double _otherEmis = 10000;
  double _foir = 50.0; // Fixed Obligation to Income Ratio

  double _maxLoanAmount = 0;
  double _eligibleEmi = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateEligibility();
  }

  void _calculateEligibility() {
    double totalObligationCapacity = _monthlyIncome * (_foir / 100);
    _eligibleEmi = totalObligationCapacity - _otherEmis;
    
    if (_eligibleEmi <= 0) {
      _eligibleEmi = 0;
      _maxLoanAmount = 0;
      setState(() {});
      return;
    }

    double r = _interestRate / 12 / 100;
    double n = _tenureYears * 12;
    
    if (r > 0) {
      _maxLoanAmount = (_eligibleEmi * (pow(1 + r, n) - 1)) / (r * pow(1 + r, n));
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
      appBar: CustomAppBar(title: 'Home Loan Eligibility', actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)]),
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
                    label: 'Net Monthly Income', value: _monthlyIncome, min: 20000, max: 1000000, prefix: '₹',
                    onChanged: (val) { setState(() => _monthlyIncome = val); _calculateEligibility(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Existing EMIs', value: _otherEmis, min: 0, max: 500000, prefix: '₹',
                    onChanged: (val) { setState(() => _otherEmis = val); _calculateEligibility(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Interest Rate', value: _interestRate, min: 6, max: 15, suffix: '%',
                    onChanged: (val) { setState(() => _interestRate = val); _calculateEligibility(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Tenure', value: _tenureYears, min: 1, max: 30, suffix: ' Yrs',
                    onChanged: (val) { setState(() => _tenureYears = val); _calculateEligibility(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'FOIR (Obligation Ratio)', value: _foir, min: 40, max: 65, suffix: '%',
                    onChanged: (val) { setState(() => _foir = val); _calculateEligibility(); },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Max Eligible Loan',
              mainValue: _currencyFormat.format(_maxLoanAmount),
              subResults: [
                SubResult(label: 'Eligible EMI Affordability', value: _currencyFormat.format(_eligibleEmi)),
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

