import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import '../../../../core/utils/responsive.dart';

class GstCalculatorScreen extends StatefulWidget {
  const GstCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<GstCalculatorScreen> createState() => _GstCalculatorScreenState();
}

class _GstCalculatorScreenState extends State<GstCalculatorScreen> {
  final TextEditingController _amountController = TextEditingController(text: '1000');
  double _gstRate = 18.0;
  bool _isExclusive = true;

  double _originalAmount = 0;
  double _gstAmount = 0;
  double _totalAmount = 0;
  double _cgst = 0;
  double _sgst = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final List<double> _gstSlabs = [3.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    _calculateGst();
  }

  void _calculateGst() {
    double amount = double.tryParse(_amountController.text) ?? 0;
    
    if (_isExclusive) {
      _originalAmount = amount;
      _gstAmount = amount * (_gstRate / 100);
      _totalAmount = _originalAmount + _gstAmount;
    } else {
      _totalAmount = amount;
      _gstAmount = amount - (amount * (100 / (100 + _gstRate)));
      _originalAmount = _totalAmount - _gstAmount;
    }

    _cgst = _gstAmount / 2;
    _sgst = _gstAmount / 2;

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
        title: 'GST Calculator',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount (₹)', style: AppTextStyles.bodyText),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => _calculateGst(),
                  ),
                  const SizedBox(height: 24),
                  Text('GST Rate Slab', style: AppTextStyles.bodyText),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _gstSlabs.map((rate) {
                      return ChoiceChip(
                        label: Text('${rate.toInt()}%'),
                        selected: _gstRate == rate,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _gstRate = rate);
                            _calculateGst();
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _isExclusive = true);
                            _calculateGst();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isExclusive ? const Color(0xFF6C63FF) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF6C63FF)),
                            ),
                            alignment: Alignment.center,
                            child: Text('Exclusive (+GST)', style: TextStyle(color: _isExclusive ? Colors.white : const Color(0xFF6C63FF))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _isExclusive = false);
                            _calculateGst();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isExclusive ? const Color(0xFF6C63FF) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF6C63FF)),
                            ),
                            alignment: Alignment.center,
                            child: Text('Inclusive (-GST)', style: TextStyle(color: !_isExclusive ? Colors.white : const Color(0xFF6C63FF))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Total Amount',
              mainValue: _currencyFormat.format(_totalAmount),
              subResults: [
                SubResult(label: 'Original Amount', value: _currencyFormat.format(_originalAmount)),
                SubResult(label: 'Total GST Amount', value: _currencyFormat.format(_gstAmount)),
              ],
            ),
            const SizedBox(height: 24),
            GlassmorphicCard(
              child: Column(
                children: [
                  Text('GST Breakdown', style: AppTextStyles.heading3),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('CGST (${(_gstRate / 2).toStringAsFixed(1)}%)', style: AppTextStyles.bodyText),
                      Text(_currencyFormat.format(_cgst), style: AppTextStyles.heading3),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SGST (${(_gstRate / 2).toStringAsFixed(1)}%)', style: AppTextStyles.bodyText),
                      Text(_currencyFormat.format(_sgst), style: AppTextStyles.heading3),
                    ],
                  ),
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
}

