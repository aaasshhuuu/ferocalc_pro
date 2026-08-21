import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

class CagrCalculatorScreen extends StatefulWidget {
  const CagrCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<CagrCalculatorScreen> createState() => _CagrCalculatorScreenState();
}

class _CagrCalculatorScreenState extends State<CagrCalculatorScreen> {
  final TextEditingController _beginCtrl = TextEditingController(text: '10000');
  final TextEditingController _endCtrl = TextEditingController(text: '20000');
  final TextEditingController _yearsCtrl = TextEditingController(text: '5');

  double _cagr = 0;
  double _absReturn = 0;

  @override
  void initState() {
    super.initState();
    _calculateCagr();
  }

  void _calculateCagr() {
    double begin = double.tryParse(_beginCtrl.text) ?? 10000;
    double end = double.tryParse(_endCtrl.text) ?? 20000;
    double years = double.tryParse(_yearsCtrl.text) ?? 5;
    
    if (begin > 0 && years > 0) {
      _cagr = (pow((end / begin), (1 / years)) - 1) * 100;
      _absReturn = ((end - begin) / begin) * 100;
    } else {
      _cagr = 0;
      _absReturn = 0;
    }
    setState(() {});
  }

  void _shareResult(BuildContext context) {
    final text = 'FeroCalc CAGR Calculator\n\nBeginning Value: ${_beginCtrl.text}\nEnding Value: ${_endCtrl.text}\nYears: ${_yearsCtrl.text}\nCAGR: ${_cagr.toStringAsFixed(2)}%\nAbsolute Return: ${_absReturn.toStringAsFixed(2)}%\n\nDownload FeroCalc for more!';
    Share.share(text);
  }

  void _exportPdf(BuildContext context) {
    final text = 'FeroCalc CAGR Report\n\nBeginning Value: ${_beginCtrl.text}\nEnding Value: ${_endCtrl.text}\nYears: ${_yearsCtrl.text}\nCAGR: ${_cagr.toStringAsFixed(2)}%\nAbsolute Return: ${_absReturn.toStringAsFixed(2)}%';
    Share.share(text, subject: 'FeroCalc - CAGR Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'CAGR Calculator',
        actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), const SizedBox(width: 16)],
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
                  _buildTextField('Beginning Value', _beginCtrl),
                  const SizedBox(height: 16),
                  _buildTextField('Ending Value', _endCtrl),
                  const SizedBox(height: 16),
                  _buildTextField('Number of Years', _yearsCtrl),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'CAGR',
              mainValue: '${_cagr.toStringAsFixed(2)}%',
              subResults: [
                SubResult(label: 'Absolute Return', value: '${_absReturn.toStringAsFixed(2)}%'),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Text(
                'Disclaimer: Results are for informational purposes only. Not financial advice.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey),
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
          ),
          onChanged: (val) => _calculateCagr(),
        ),
      ],
    );
  }
}
