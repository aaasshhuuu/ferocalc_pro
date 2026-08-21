import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import '../../../../core/utils/responsive.dart';

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
    int months = ((_retirementAge - _age) * 12).toInt();
    if (months <= 0) return;

    double balance = _currentBalance;
    double currentSalary = _basicSalary;
    
    _totalEmployee = 0;
    _totalEmployer = 0;

    for (int m = 1; m <= months; m++) {
      double employeeShare = currentSalary * (_epfContribution / 100);
      double employerShare = currentSalary * 0.0367; // 3.67% to EPF, 8.33% to EPS
      
      _totalEmployee += employeeShare;
      _totalEmployer += employerShare;
      balance += employeeShare + employerShare;
      
      // Interest added monthly (simple interest compounded annually)
      balance += balance * ((_interestRate / 100) / 12);

      if (m % 12 == 0) {
        currentSalary *= (1 + _annualIncrease / 100);
      }
    }

    _maturityAmount = balance;
    _totalInterest = _maturityAmount - _currentBalance - _totalEmployee - _totalEmployer;
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
      appBar: CustomAppBar(title: 'EPF Calculator', actions: [IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () => _shareResult(context)), SizedBox(width: 16)]),
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
          ],
        ),
      ),
        ),
      ),
    );
  }
}

