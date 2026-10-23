import 'package:flutter/material.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import 'package:intl/intl.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

import 'package:fincalc_pro/core/widgets/calculator_purpose_card.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import '../../../../core/utils/responsive.dart';
import 'package:fincalc_pro/features/history/presentation/helper/calculation_history_saver.dart';

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

  void _calculateAndSave() {
    _calculateYield();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'dividend_yield',
      calculatorName: 'Dividend Yield',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Current Dividend Yield',
      primaryResultValue: '${_currentYield.toStringAsFixed(2)}%',
      category: 'Investments',
    );
  }


  Map<String, String> _getInputs() => {
    'Stock Price': '₹${_priceCtrl.text}',
    'Annual Dividend / Share': '₹${_divCtrl.text}',
    'Total Shares': _sharesCtrl.text,
    'Dividend Growth Rate': '${_growthCtrl.text}%',
    'Investment Horizon': '${_yearsCtrl.text} Years',
  };

  Map<String, String> _getResults() => {
    'Current Dividend Yield': '${_currentYield.toStringAsFixed(2)}%',
    'Annual Dividend Income': _currencyFormat.format(_annualIncome),
    'Total Dividend Over Period': _currencyFormat.format(_totalDividend),
    'Yield on Cost': '${_yieldOnCost.toStringAsFixed(2)}%',
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Dividend Yield',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Dividend Yield',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Dividend Yield',
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
            const SizedBox(height: 16),
            GradientButton(
              key: const ValueKey('calculate_button'),
              text: 'Calculate',
              onPressed: _calculateAndSave,
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
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'dividend_yield'),
            const SizedBox(height: 24),
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

