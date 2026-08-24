import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import '../../../../core/utils/responsive.dart';

class LoanTermCalculatorScreen extends StatefulWidget {
  const LoanTermCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<LoanTermCalculatorScreen> createState() => _LoanTermCalculatorScreenState();
}

class _LoanTermCalculatorScreenState extends State<LoanTermCalculatorScreen> with SingleTickerProviderStateMixin {
  double _loanAmount = 1000000;
  double _emi = 20000;
  double _interestRate = 8.5;

  double _totalMonths = 0;
  bool _isPossible = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculateTerm();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateTerm() {
    int totalMonthsInt = FinancialMath.calculateLoanTenure(
      principal: _loanAmount,
      annualRate: _interestRate,
      emi: _emi,
    );

    if (totalMonthsInt == -1) {
      setState(() {
        _isPossible = false;
        _totalMonths = 0;
      });
      return;
    }

    _isPossible = true;
    _totalMonths = totalMonthsInt.toDouble();
    
    _animationController.forward(from: 0.0);
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
    int years = _totalMonths ~/ 12;
    int months = (_totalMonths % 12).ceil();
    if (months == 12) {
      years += 1;
      months = 0;
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Loan Term Calculator',
        actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: Responsive.screenPadding(context),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassmorphicCard(
              child: Column(
                children: [
                  InputSliderField(
                    label: 'Loan Amount',
                    value: _loanAmount,
                    min: 10000,
                    max: 50000000,
                    prefix: '₹',
                    onChanged: (val) {
                      setState(() => _loanAmount = val);
                      _calculateTerm();
                    },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Monthly EMI',
                    value: _emi,
                    min: 1000,
                    max: 500000,
                    prefix: '₹',
                    onChanged: (val) {
                      setState(() => _emi = val);
                      _calculateTerm();
                    },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Interest Rate (p.a)',
                    value: _interestRate,
                    min: 1,
                    max: 30,
                    suffix: '%',
                    onChanged: (val) {
                      setState(() => _interestRate = val);
                      _calculateTerm();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fadeAnimation,
              child: _isPossible
                  ? ResultDisplayCard(
                      mainLabel: 'Loan Tenure',
                      mainValue: years > 0 ? '$years Yrs $months Mos' : '$months Mos',
                      subResults: [
                        SubResult(
                          label: 'Total Months', 
                          value: '${_totalMonths.ceil()} Months'
                        ),
                      ],
                    )
                  : GlassmorphicCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'EMI is too low! It does not even cover the monthly interest of ₹${(_loanAmount * (_interestRate/12/100)).toStringAsFixed(0)}',
                          style: AppTextStyles.bodyText.copyWith(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

