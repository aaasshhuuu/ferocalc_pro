import 'package:flutter/material.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';

import 'package:fincalc_pro/core/widgets/calculator_purpose_card.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import '../../../../core/utils/responsive.dart';
import 'package:fincalc_pro/features/history/presentation/helper/calculation_history_saver.dart';

class InterestRateCalculatorScreen extends StatefulWidget {
  const InterestRateCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<InterestRateCalculatorScreen> createState() => _InterestRateCalculatorScreenState();
}

class _InterestRateCalculatorScreenState extends State<InterestRateCalculatorScreen> with SingleTickerProviderStateMixin {
  double _loanAmount = 1000000;
  double _emi = 12500;
  double _tenure = 10;
  bool _isMonths = false;

  double _calculatedRate = 0;
  double _flatRate = 0;
  bool _isPossible = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculateRate();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateRate() {
    double n = _isMonths ? _tenure : _tenure * 12;

    if (_emi * n <= _loanAmount) {
      setState(() {
        _isPossible = false;
        _calculatedRate = 0;
        _flatRate = 0;
      });
      return;
    }

    _isPossible = true;
    
    _calculatedRate = FinancialMath.calculateInterestRate(
      principal: _loanAmount,
      emi: _emi,
      months: n.toInt(),
    );

    _flatRate = FinancialMath.calculateFlatInterestRate(
      principal: _loanAmount,
      emi: _emi,
      months: n.toInt(),
    );
    
    _animationController.forward(from: 0.0);
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateRate();
    if (!_isPossible) return;
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'interest_rate',
      calculatorName: 'Interest Rate Calculator',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Effective Rate (Reducing)',
      primaryResultValue: '${_calculatedRate.toStringAsFixed(2)}%',
      category: 'Loans',
    );
  }


  Map<String, String> _getInputs() => {
    'Loan Amount': _currencyFormat.format(_loanAmount),
    'Monthly EMI': _currencyFormat.format(_emi),
    'Tenure': '${_tenure.toInt()} ${_isMonths ? 'months' : 'years'}',
  };

  Map<String, String> _getResults() => {
    'Effective Rate (Reducing)': _isPossible ? '${_calculatedRate.toStringAsFixed(2)}% p.a.' : 'Not possible with current EMI',
    'Flat Rate (Simple Interest)': _isPossible ? '${_flatRate.toStringAsFixed(2)}% p.a.' : 'Not possible with current EMI',
    'Total Payment': _currencyFormat.format(_emi * (_isMonths ? _tenure : _tenure * 12)),
    'Total Interest': _currencyFormat.format((_emi * (_isMonths ? _tenure : _tenure * 12)) - _loanAmount),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Interest Rate Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Interest Rate Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Interest Rate Calculator',
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
                      _calculateRate();
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
                      _calculateRate();
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text('Tenure in', style: AppTextStyles.bodyText),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Years'),
                            selected: !_isMonths,
                            onSelected: (val) {
                              setState(() {
                                _isMonths = false;
                                _tenure = (_tenure / 12).clamp(1, 30);
                              });
                              _calculateRate();
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Months'),
                            selected: _isMonths,
                            onSelected: (val) {
                              setState(() {
                                _isMonths = true;
                                _tenure = (_tenure * 12).clamp(1, 360);
                              });
                              _calculateRate();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InputSliderField(
                    label: 'Tenure',
                    value: _tenure,
                    min: 1,
                    max: _isMonths ? 360 : 30,
                    suffix: _isMonths ? ' mo' : ' yr',
                    onChanged: (val) {
                      setState(() => _tenure = val);
                      _calculateRate();
                    },
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
            FadeTransition(
              opacity: _fadeAnimation,
              child: _isPossible
                  ? ResultDisplayCard(
                      mainLabel: 'Effective Interest Rate (Reducing)',
                      mainValue: '${_calculatedRate.toStringAsFixed(2)}%',
                      subResults: [
                        SubResult(
                          label: 'Flat Rate (Simple Interest)',
                          value: '${_flatRate.toStringAsFixed(2)}% p.a.',
                        ),
                        SubResult(
                          label: 'Total Interest',
                          value: _currencyFormat.format((_emi * (_isMonths ? _tenure : _tenure * 12)) - _loanAmount),
                        ),
                        SubResult(
                          label: 'Total Payment',
                          value: _currencyFormat.format(_emi * (_isMonths ? _tenure : _tenure * 12)),
                        ),
                      ],
                    )
                  : GlassmorphicCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Invalid inputs! Total EMI paid is less than the Loan Amount.',
                          style: AppTextStyles.bodyText.copyWith(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'interest_rate'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

