import 'package:flutter/material.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import 'package:intl/intl.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

import 'package:fincalc_pro/core/widgets/calculator_purpose_card.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/features/history/presentation/helper/calculation_history_saver.dart';
import '../../../../core/utils/responsive.dart';

class IncomeTaxCalculatorScreen extends StatefulWidget {
  const IncomeTaxCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<IncomeTaxCalculatorScreen> createState() => _IncomeTaxCalculatorScreenState();
}

class _IncomeTaxCalculatorScreenState extends State<IncomeTaxCalculatorScreen> {
  double _annualIncome = 1200000;
  double _deductions80c = 150000;
  double _otherDeductions = 50000;
  
  double _taxOldRegime = 0;
  double _taxNewRegime = 0;
  String _recommended = '';
  double _taxSaved = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateTax();
  }

  void _calculateTax() {
    _taxOldRegime = FinancialMath.calculateIncomeTaxOldRegime(
      grossIncome: _annualIncome,
      ageGroup: 0,
      deduction80C: _deductions80c,
      otherDeductions: _otherDeductions,
      standardDeduction: 50000,
    );
    _taxNewRegime = FinancialMath.calculateIncomeTaxNewRegime(_annualIncome);
    
    if (_taxOldRegime < _taxNewRegime) {
      _recommended = 'Old Regime';
      _taxSaved = _taxNewRegime - _taxOldRegime;
    } else {
      _recommended = 'New Regime';
      _taxSaved = _taxOldRegime - _taxNewRegime;
    }
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateTax();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'income_tax',
      calculatorName: 'Income Tax',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Recommended: $_recommended',
      primaryResultValue: _currencyFormat.format(_recommended == 'Old Regime' ? _taxOldRegime : _taxNewRegime),
      category: 'Tax & GST',
    );
  }

  Map<String, String> _getInputs() => {
    'Annual Gross Income': _currencyFormat.format(_annualIncome),
    '80C Deductions': _currencyFormat.format(_deductions80c),
    'Other Deductions': _currencyFormat.format(_otherDeductions),
    'Standard Deduction': '₹50,000',
  };

  Map<String, String> _getResults() => {
    'Tax under Old Regime': _currencyFormat.format(_taxOldRegime),
    'Tax under New Regime': _currencyFormat.format(_taxNewRegime),
    'Recommended Regime': _recommended,
    'Tax Savings': _currencyFormat.format(_taxSaved),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Income Tax',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Income Tax',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Income Tax',
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
                    label: 'Annual Income', value: _annualIncome, min: 300000, max: 5000000, prefix: '₹',
                    onChanged: (val) { setState(() => _annualIncome = val); _calculateTax(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: '80C Deductions (Max 1.5L)', value: _deductions80c, min: 0, max: 150000, prefix: '₹',
                    onChanged: (val) { setState(() => _deductions80c = val); _calculateTax(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Other Deductions (80D, HRA etc)', value: _otherDeductions, min: 0, max: 500000, prefix: '₹',
                    onChanged: (val) { setState(() => _otherDeductions = val); _calculateTax(); },
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
              mainLabel: 'Recommended: $_recommended',
              mainValue: _currencyFormat.format(_recommended == 'Old Regime' ? _taxOldRegime : _taxNewRegime),
              subResults: [
                SubResult(label: 'Tax (Old Regime)', value: _currencyFormat.format(_taxOldRegime)),
                SubResult(label: 'Tax (New Regime)', value: _currencyFormat.format(_taxNewRegime)),
                SubResult(label: 'Tax Saved', value: _currencyFormat.format(_taxSaved)),
              ],
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'income_tax'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

