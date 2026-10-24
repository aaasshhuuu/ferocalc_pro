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

class LoanAmountCalculatorScreen extends StatefulWidget {
  const LoanAmountCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<LoanAmountCalculatorScreen> createState() => _LoanAmountCalculatorScreenState();
}

class _LoanAmountCalculatorScreenState extends State<LoanAmountCalculatorScreen> with SingleTickerProviderStateMixin {
  double _emi = 25000;
  double _interestRate = 8.5;
  double _tenure = 10;
  bool _isMonths = false;
  bool _isFlatRate = false;

  double _maxLoanAmount = 0;
  double _totalPayment = 0;
  double _totalInterest = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculateLoanAmount();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateLoanAmount() {
    double n = _isMonths ? _tenure : _tenure * 12;

    if (_isFlatRate) {
      _maxLoanAmount = FinancialMath.calculateFlatRateLoanAmount(
        emi: _emi,
        annualRate: _interestRate,
        months: n.toInt(),
      );
    } else {
      _maxLoanAmount = FinancialMath.calculateLoanAmount(
        emi: _emi,
        annualRate: _interestRate,
        months: n.toInt(),
      );
    }
    
    _totalPayment = _emi * n;
    _totalInterest = _totalPayment - _maxLoanAmount;
    
    _animationController.forward(from: 0.0);
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateLoanAmount();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'loan_amount',
      calculatorName: 'Loan Amount Calculator',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Maximum Loan Amount',
      primaryResultValue: _currencyFormat.format(_maxLoanAmount),
      category: 'Loans',
    );
  }


  Map<String, String> _getInputs() => {
    'Monthly EMI': _currencyFormat.format(_emi),
    'Interest Rate': '${_interestRate.toStringAsFixed(2)}% p.a.',
    'Tenure': '${_tenure.toInt()} ${_isMonths ? 'months' : 'years'}',
    'Method': _isFlatRate ? 'Flat Rate' : 'Reducing Balance',
  };

  Map<String, String> _getResults() => {
    'Maximum Loan Amount': _currencyFormat.format(_maxLoanAmount),
    'Total Payment': _currencyFormat.format(_totalPayment),
    'Total Interest': _currencyFormat.format(_totalInterest),
    'Method': _isFlatRate ? 'Flat Rate' : 'Reducing Balance',
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Loan Amount Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Loan Amount Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Loan Amount Calculator',
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: () => _exportPdf(context)),
          SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)),
          SizedBox(width: 16),
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text('Interest Method', style: AppTextStyles.bodyText),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            key: const ValueKey('loan_amount_method_reducing'),
                            label: const Text('Reducing Balance'),
                            selected: !_isFlatRate,
                            onSelected: (val) {
                              setState(() => _isFlatRate = false);
                              _calculateLoanAmount();
                            },
                          ),
                          ChoiceChip(
                            key: const ValueKey('loan_amount_method_flat'),
                            label: const Text('Flat Rate'),
                            selected: _isFlatRate,
                            onSelected: (val) {
                              setState(() => _isFlatRate = true);
                              _calculateLoanAmount();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isFlatRate
                          ? 'Flat-rate interest calculated on the original principal.'
                          : 'Reducing-balance loan interest calculated on the outstanding balance.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Monthly EMI you can afford',
                    value: _emi,
                    min: 1000,
                    max: 500000,
                    prefix: '₹',
                    onChanged: (val) {
                      setState(() => _emi = val);
                      _calculateLoanAmount();
                    },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Interest Rate (p.a)',
                    value: _interestRate,
                    min: 1,
                    max: 30,
                    suffix: '%',
                    onChanged: (val) {
                      setState(() => _interestRate = val);
                      _calculateLoanAmount();
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
                              _calculateLoanAmount();
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
                              _calculateLoanAmount();
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
                      _calculateLoanAmount();
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
              child: ResultDisplayCard(
                mainLabel: 'Maximum Loan Amount',
                mainValue: _currencyFormat.format(_maxLoanAmount),
                subResults: [
                  SubResult(label: 'Total Interest payable', value: _currencyFormat.format(_totalInterest)),
                  SubResult(label: 'Total Payment', value: _currencyFormat.format(_totalPayment)),
                  SubResult(label: 'Calculation Method', value: _isFlatRate ? 'Flat Rate' : 'Reducing Balance'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'loan_amount'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

