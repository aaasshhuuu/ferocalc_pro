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

class PersonalLoanEligibilityScreen extends StatefulWidget {
  const PersonalLoanEligibilityScreen({Key? key}) : super(key: key);

  @override
  State<PersonalLoanEligibilityScreen> createState() => _PersonalLoanEligibilityScreenState();
}

class _PersonalLoanEligibilityScreenState extends State<PersonalLoanEligibilityScreen> {
  double _monthlyIncome = 50000;
  double _interestRate = 12.0;
  double _tenureYears = 5;
  double _otherEmis = 5000;
  double _foir = 50.0; 

  double _maxLoanAmount = 0;
  double _eligibleEmi = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateEligibility();
  }  void _calculateEligibility() {
    final result = FinancialMath.calculateHomeLoanEligibility(
      monthlyIncome: _monthlyIncome,
      monthlyExpenses: 0,
      annualRate: _interestRate,
      tenureMonths: (_tenureYears * 12).toInt(),
      existingEMIs: _otherEmis,
      foir: _foir,
    );

    _eligibleEmi = result['eligibleEMI'] ?? 0;
    _maxLoanAmount = result['maxLoanAmount'] ?? 0;
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateEligibility();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'personal_loan_eligibility',
      calculatorName: 'Personal Loan Eligibility',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Max Eligible Loan',
      primaryResultValue: _currencyFormat.format(_maxLoanAmount),
      category: 'Loans',
    );
  }


  Map<String, String> _getInputs() => {
    'Net Monthly Income': _currencyFormat.format(_monthlyIncome),
    'Interest Rate': '${_interestRate.toStringAsFixed(2)}% p.a.',
    'Tenure': '${_tenureYears.toInt()} Years',
    'Existing Other EMIs': _currencyFormat.format(_otherEmis),
    'Max FOIR Ratio': '${_foir.toStringAsFixed(0)}%',
  };

  Map<String, String> _getResults() => {
    'Maximum Loan Eligibility': _currencyFormat.format(_maxLoanAmount),
    'Maximum Allowable EMI': _currencyFormat.format(_eligibleEmi),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Personal Loan Eligibility',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Personal Loan Eligibility',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Personal Loan Eligibility',
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
                    label: 'Net Monthly Income', value: _monthlyIncome, min: 15000, max: 500000, prefix: '₹',
                    onChanged: (val) { setState(() => _monthlyIncome = val); _calculateEligibility(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Existing EMIs', value: _otherEmis, min: 0, max: 200000, prefix: '₹',
                    onChanged: (val) { setState(() => _otherEmis = val); _calculateEligibility(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Interest Rate', value: _interestRate, min: 9, max: 24, suffix: '%',
                    onChanged: (val) { setState(() => _interestRate = val); _calculateEligibility(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Tenure', value: _tenureYears, min: 1, max: 7, suffix: ' Yrs',
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
            const SizedBox(height: 16),
            GradientButton(
              key: const ValueKey('calculate_button'),
              text: 'Calculate',
              onPressed: _calculateAndSave,
            ),
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Max Eligible Loan',
              mainValue: _currencyFormat.format(_maxLoanAmount),
              subResults: [
                SubResult(label: 'Eligible EMI Affordability', value: _currencyFormat.format(_eligibleEmi)),
              ],
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'personal_loan_eligibility'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

