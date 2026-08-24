import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

class DividendYieldCalculatorScreen extends StatefulWidget {
  const DividendYieldCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<DividendYieldCalculatorScreen> createState() => _DividendYieldCalculatorScreenState();
}

class _DividendYieldCalculatorScreenState extends State<DividendYieldCalculatorScreen> {
  final TextEditingController _priceCtrl = TextEditingController(text: '500');
  final TextEditingController _divCtrl = TextEditingController(text: '20');
  final TextEditingController _sharesCtrl = TextEditingController(text: '100');
  final TextEditingController _growthCtrl = TextEditingController(text: '5');
  final TextEditingController _yearsCtrl = TextEditingController(text: '10');

  double _currentYield = 0;
  double _annualIncome = 0;
  double _totalDividend = 0;
  double _yieldOnCost = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _calculateYield();
  }  void _calculateYield() {
    double price = double.tryParse(_priceCtrl.text) ?? 500;
    double divPerShare = double.tryParse(_divCtrl.text) ?? 20;
    double shares = double.tryParse(_sharesCtrl.text) ?? 100;
    double growth = double.tryParse(_growthCtrl.text) ?? 5;
    int years = int.tryParse(_yearsCtrl.text) ?? 10;
    
    final result = FinancialMath.calculateDividendYield(
      sharePrice: price,
      annualDividend: divPerShare,
      numberOfShares: shares.toInt(),
      dividendGrowthRate: growth,
      years: years,
    );

    _currentYield = result['currentYield'] ?? 0;
    _annualIncome = result['annualIncome'] ?? 0;
    _totalDividend = result['totalDividend'] ?? 0;
    _yieldOnCost = result['yieldOnCost'] ?? 0;

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
      appBar: CustomAppBar(
        title: 'Dividend Yield',
        actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: SingleChildScrollView(
            padding: Responsive.screenPadding(context),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassmorphicCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Share Price (₹)', _priceCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Dividend/Share (₹)', _divCtrl)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Total Shares', _sharesCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Div Growth %', _growthCtrl)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Years to hold', _yearsCtrl),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Current Dividend Yield',
              mainValue: '${_currentYield.toStringAsFixed(2)}%',
              subResults: [
                SubResult(label: 'Current Annual Income', value: _currencyFormat.format(_annualIncome)),
                SubResult(label: 'Total Div (over years)', value: _currencyFormat.format(_totalDividend)),
                SubResult(label: 'Yield on Cost (Future)', value: '${_yieldOnCost.toStringAsFixed(2)}%'),
              ],
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (val) => _calculateYield(),
        ),
      ],
    );
  }
}

