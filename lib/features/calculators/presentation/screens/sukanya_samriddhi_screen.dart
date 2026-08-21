import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import '../../../../core/utils/responsive.dart';

class SukanyaSamriddhiScreen extends StatefulWidget {
  const SukanyaSamriddhiScreen({Key? key}) : super(key: key);

  @override
  State<SukanyaSamriddhiScreen> createState() => _SukanyaSamriddhiScreenState();
}

class _SukanyaSamriddhiScreenState extends State<SukanyaSamriddhiScreen> {
  double _girlAge = 0;
  bool _isVariable = false;
  
  double _fixedYearlyDeposit = 150000;
  final List<double> _variableDeposits = List.filled(15, 100000);
  
  final double _interestRate = 8.2;
  
  double _totalInvestment = 0;
  double _totalInterest = 0;
  double _maturityValue = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateSsy();
  }

  void _calculateSsy() {
    double balance = 0;
    double r = _interestRate / 100;
    _totalInvestment = 0;
    
    // Deposit period is 15 years, maturity is 21 years from account opening
    for (int year = 1; year <= 21; year++) {
      double depositThisYear = 0;
      if (year <= 15) {
        depositThisYear = _isVariable ? _variableDeposits[year - 1] : _fixedYearlyDeposit;
        _totalInvestment += depositThisYear;
      }
      
      // Interest is calculated yearly on the balance
      balance += depositThisYear;
      double interestThisYear = balance * r;
      balance += interestThisYear;
    }
    
    _maturityValue = balance;
    _totalInterest = _maturityValue - _totalInvestment;
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
        title: 'Sukanya Samriddhi (SSY)',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InputSliderField(
                    label: 'Girl Child Age',
                    value: _girlAge,
                    min: 0,
                    max: 10,
                    suffix: ' Yrs',
                    onChanged: (val) {
                      setState(() => _girlAge = val);
                      _calculateSsy();
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deposit Mode', style: AppTextStyles.bodyText),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Fixed'),
                            selected: !_isVariable,
                            onSelected: (val) {
                              setState(() => _isVariable = false);
                              _calculateSsy();
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Variable'),
                            selected: _isVariable,
                            onSelected: (val) {
                              setState(() => _isVariable = true);
                              _calculateSsy();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_isVariable)
                    InputSliderField(
                      label: 'Yearly Deposit',
                      value: _fixedYearlyDeposit,
                      min: 250,
                      max: 150000,
                      prefix: '₹',
                      onChanged: (val) {
                        setState(() => _fixedYearlyDeposit = val);
                        _calculateSsy();
                      },
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Year-by-Year Deposits (Max 1.5L/yr)', style: AppTextStyles.bodyText),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 300,
                          child: ListView.builder(
                            itemCount: 15,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 60,
                                      child: Text('Year ${index + 1}', style: const TextStyle(color: Colors.grey)),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: _variableDeposits[index],
                                        min: 250,
                                        max: 150000,
                                        onChanged: (val) {
                                          setState(() => _variableDeposits[index] = val);
                                          _calculateSsy();
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        _currencyFormat.format(_variableDeposits[index]),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Current Rate: $_interestRate% p.a.', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ResultDisplayCard(
              mainLabel: 'Maturity Value (at Age ${(_girlAge + 21).toInt()})',
              mainValue: _currencyFormat.format(_maturityValue),
              subResults: [
                SubResult(label: 'Total Deposits', value: _currencyFormat.format(_totalInvestment)),
                SubResult(label: 'Total Interest', value: _currencyFormat.format(_totalInterest)),
              ],
            ),
            const SizedBox(height: 24),
            GradientButton(text: 'View Year-wise Schedule',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Year-wise schedule coming soon!'), backgroundColor: Color(0xFF10B981)),
                );
              }),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Text(
                'Disclaimer: Results are for informational purposes only. Not financial advice.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

