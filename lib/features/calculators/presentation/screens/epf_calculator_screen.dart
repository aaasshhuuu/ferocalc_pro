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
import '../../../../core/utils/responsive.dart';
import 'package:fincalc_pro/features/history/presentation/helper/calculation_history_saver.dart';

class EpfCalculatorScreen extends StatefulWidget {
  const EpfCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<EpfCalculatorScreen> createState() => _EpfCalculatorScreenState();
}

class _EpfCalculatorScreenState extends State<EpfCalculatorScreen> {
  double _basicSalary = 50000;
  double _age = 25;
  double _epfContribution = 12.0;
  double _annualIncrease = 5.0;
  double _currentBalance = 100000;
  double _retirementAge = 60;
  final double _interestRate = 8.15;

  double _totalEmployee = 0;
  double _totalEmployer = 0;
  double _totalInterest = 0;
  double _maturityAmount = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _calculateEpf();
  }

  void _calculateEpf() {
    final result = FinancialMath.calculateEPF(
      basicSalary: _basicSalary,
      employeeContribution: _epfContribution,
      employerContribution: 3.67,
      annualRate: _interestRate,
      annualSalaryIncrease: _annualIncrease,
      currentBalance: _currentBalance,
      currentAge: _age.toInt(),
      retirementAge: _retirementAge.toInt(),
    );
    _maturityAmount = result['maturityValue']!;
    _totalEmployee = result['totalEmployeeContribution']!;
    _totalEmployer = result['totalEmployerContribution']!;
    _totalInterest = result['totalInterest']!;
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateEpf();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'epf',
      calculatorName: 'EPF Calculator',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Maturity Amount (at Age ${_retirementAge.toInt()})',
      primaryResultValue: _currencyFormat.format(_maturityAmount),
      category: 'Investments',
    );
  }


  Map<String, String> _getInputs() => {
    'Basic Monthly Salary': _currencyFormat.format(_basicSalary),
    'Employee Contribution': '${_epfContribution.toStringAsFixed(1)}%',
    'Employer Contribution': '3.67%',
    'Current Age': '${_age.toInt()} Years',
    'Retirement Age': '${_retirementAge.toInt()} Years',
    'Existing EPF Balance': _currencyFormat.format(_currentBalance),
    'Interest Rate': '${_interestRate.toStringAsFixed(2)}% p.a.',
    'Annual Salary Increase': '${_annualIncrease.toStringAsFixed(1)}%',
  };

  Map<String, String> _getResults() => {
    'Maturity Corpus': _currencyFormat.format(_maturityAmount),
    'Total Employee Contribution': _currencyFormat.format(_totalEmployee),
    'Total Employer Contribution': _currencyFormat.format(_totalEmployer),
    'Total Interest Earned': _currencyFormat.format(_totalInterest),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'EPF Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'EPF Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'EPF Calculator',
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
                    label: 'Basic Salary + DA', value: _basicSalary, min: 10000, max: 500000, prefix: '₹',
                    onChanged: (val) { setState(() => _basicSalary = val); _calculateEpf(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Your Age', value: _age, min: 18, max: 58, suffix: ' Yrs',
                    onChanged: (val) { setState(() => _age = val); _calculateEpf(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Current EPF Balance', value: _currentBalance, min: 0, max: 5000000, prefix: '₹',
                    onChanged: (val) { setState(() => _currentBalance = val); _calculateEpf(); },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Annual Salary Increase', value: _annualIncrease, min: 0, max: 15, suffix: '%',
                    onChanged: (val) { setState(() => _annualIncrease = val); _calculateEpf(); },
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
              mainLabel: 'Maturity Amount (at Age ${_retirementAge.toInt()})',
              mainValue: _currencyFormat.format(_maturityAmount),
              subResults: [
                SubResult(label: 'Total Employee Contrib.', value: _currencyFormat.format(_totalEmployee)),
                SubResult(label: 'Total Employer Contrib.', value: _currencyFormat.format(_totalEmployer)),
                SubResult(label: 'Total Interest Earned', value: _currencyFormat.format(_totalInterest)),
              ],
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'epf'),
            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

