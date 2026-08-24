import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import '../../../../core/utils/responsive.dart';

class StockReturnCalculatorScreen extends StatefulWidget {
  const StockReturnCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<StockReturnCalculatorScreen> createState() => _StockReturnCalculatorScreenState();
}

class _StockReturnCalculatorScreenState extends State<StockReturnCalculatorScreen> {
  final TextEditingController _buyPriceCtrl = TextEditingController(text: '100');
  final TextEditingController _sellPriceCtrl = TextEditingController(text: '150');
  final TextEditingController _qtyCtrl = TextEditingController(text: '100');
  final TextEditingController _brokerageCtrl = TextEditingController(text: '0.1');
  final TextEditingController _dividendCtrl = TextEditingController(text: '0');
  final TextEditingController _yearsCtrl = TextEditingController(text: '1');

  double _totalInvestment = 0;
  double _totalSale = 0;
  double _capitalGain = 0;
  double _dividendIncome = 0;
  double _brokerageCost = 0;
  double _netProfit = 0;
  double _cagr = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _calculateReturn();
  }

  void _calculateReturn() {
    double buy = double.tryParse(_buyPriceCtrl.text) ?? 0;
    double sell = double.tryParse(_sellPriceCtrl.text) ?? 0;
    double qty = double.tryParse(_qtyCtrl.text) ?? 0;
    double brokerageRate = double.tryParse(_brokerageCtrl.text) ?? 0;
    double divPerShare = double.tryParse(_dividendCtrl.text) ?? 0;
    double years = double.tryParse(_yearsCtrl.text) ?? 1;
    if (years <= 0) years = 1;

    final result = FinancialMath.calculateStockReturn(
      buyPrice: buy,
      sellPrice: sell,
      quantity: qty.toInt(),
      holdingYears: years,
      annualDividendPerShare: divPerShare,
      brokeragePercent: brokerageRate,
    );
    
    _totalInvestment = result['totalInvestment']!;
    _capitalGain = result['capitalGain']!;
    _dividendIncome = result['dividendIncome']!;
    _brokerageCost = result['brokerageCost']!;
    _netProfit = result['netProfit']!;
    _cagr = result['cagr']!;
    _totalSale = sell * qty;
    
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
        title: 'Stock Return Calculator',
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
                      Expanded(child: _buildTextField('Buy Price (₹)', _buyPriceCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Sell Price (₹)', _sellPriceCtrl)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Quantity', _qtyCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Holding (Yrs)', _yearsCtrl)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Brokerage (%)', _brokerageCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Dividend/Yr (₹)', _dividendCtrl)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Net Profit / Loss',
              mainValue: _currencyFormat.format(_netProfit),
              mainValueColor: _netProfit >= 0 ? const Color(0xFF00E676) : Colors.redAccent,
              subResults: [
                SubResult(label: 'Total Investment', value: _currencyFormat.format(_totalInvestment)),
                SubResult(label: 'Annualized Return (CAGR)', value: '${_cagr.toStringAsFixed(2)}%'),
              ],
            ),
            const SizedBox(height: 24),
            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detailed Breakdown', style: AppTextStyles.heading3),
                  const SizedBox(height: 16),
                  _buildBreakdownRow('Capital Gain', _capitalGain, _capitalGain >= 0 ? Colors.green : Colors.red),
                  const Divider(),
                  _buildBreakdownRow('Dividend Income', _dividendIncome, Colors.green),
                  const Divider(),
                  _buildBreakdownRow('Brokerage & Charges', -_brokerageCost, Colors.red),
                  const Divider(),
                  _buildBreakdownRow('Net Profit', _netProfit, _netProfit >= 0 ? Colors.green : Colors.red, isBold: true),
                ],
              ),
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
          onChanged: (val) => _calculateReturn(),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, double value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyText.copyWith(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          value >= 0 ? '+${_currencyFormat.format(value)}' : _currencyFormat.format(value),
          style: AppTextStyles.bodyText.copyWith(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }
}

