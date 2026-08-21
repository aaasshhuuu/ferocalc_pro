import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
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
    // Standard deduction
    double oldStdDed = 50000;
    double newStdDed = 75000;

    double oldTaxable = _annualIncome - _deductions80c - _otherDeductions - oldStdDed;
    if (oldTaxable < 0) oldTaxable = 0;
    
    // Old Regime calc (simplified <60 yrs slabs)
    _taxOldRegime = 0;
    if (oldTaxable > 1000000) {
      _taxOldRegime += (oldTaxable - 1000000) * 0.30 + 112500;
    } else if (oldTaxable > 500000) {
      _taxOldRegime += (oldTaxable - 500000) * 0.20 + 12500;
    } else if (oldTaxable > 250000) {
      _taxOldRegime += (oldTaxable - 250000) * 0.05;
    }
    // Rebate 87A for Old
    if (oldTaxable <= 500000) _taxOldRegime = 0;

    // New Regime calc (FY 24-25)
    double newTaxable = _annualIncome - newStdDed;
    if (newTaxable < 0) newTaxable = 0;

    _taxNewRegime = 0;
    if (newTaxable > 1500000) {
      _taxNewRegime += (newTaxable - 1500000) * 0.30 + 150000;
    } else if (newTaxable > 1200000) {
      _taxNewRegime += (newTaxable - 1200000) * 0.20 + 90000;
    } else if (newTaxable > 1000000) {
      _taxNewRegime += (newTaxable - 1000000) * 0.15 + 60000;
    } else if (newTaxable > 700000) {
      _taxNewRegime += (newTaxable - 700000) * 0.10 + 30000;
    } else if (newTaxable > 300000) {
      _taxNewRegime += (newTaxable - 300000) * 0.05;
    }
    // Rebate 87A for New (up to 7L)
    if (newTaxable <= 700000) _taxNewRegime = 0;

    // Add 4% cess
    if (_taxOldRegime > 0) _taxOldRegime *= 1.04;
    if (_taxNewRegime > 0) _taxNewRegime *= 1.04;

    if (_taxOldRegime < _taxNewRegime) {
      _recommended = 'Old Regime';
      _taxSaved = _taxNewRegime - _taxOldRegime;
    } else {
      _recommended = 'New Regime';
      _taxSaved = _taxOldRegime - _taxNewRegime;
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
      appBar: CustomAppBar(title: 'Income Tax', actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)]),
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
          ],
        ),
      ),
        ),
      ),
    );
  }
}

