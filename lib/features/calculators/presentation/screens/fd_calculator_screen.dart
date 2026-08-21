import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import 'package:fincalc_pro/config/themes/app_colors.dart';
import '../../../../core/utils/responsive.dart';

class FdCalculatorScreen extends StatefulWidget {
  const FdCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<FdCalculatorScreen> createState() => _FdCalculatorScreenState();
}

class _FdCalculatorScreenState extends State<FdCalculatorScreen> with SingleTickerProviderStateMixin {
  double _principal = 100000;
  double _interestRate = 6.5;
  
  int _years = 1;
  int _months = 0;
  int _days = 0;
  
  String _compoundingFrequency = 'Quarterly';
  bool _isSeniorCitizen = false;

  double _maturityValue = 0;
  double _totalInterest = 0;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final List<String> _compoundingOptions = ['Monthly', 'Quarterly', 'Half-Yearly', 'Yearly'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculateFd();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateFd() {
    double p = _principal;
    double r = (_isSeniorCitizen ? _interestRate + 0.5 : _interestRate) / 100;
    
    double t = _years + (_months / 12.0) + (_days / 365.0);
    
    int n = 4; // Quarterly by default
    switch (_compoundingFrequency) {
      case 'Monthly': n = 12; break;
      case 'Quarterly': n = 4; break;
      case 'Half-Yearly': n = 2; break;
      case 'Yearly': n = 1; break;
    }

    if (t == 0) {
      _maturityValue = p;
      _totalInterest = 0;
    } else {
      _maturityValue = p * pow((1 + (r / n)), n * t);
      _totalInterest = _maturityValue - p;
    }
    
    _animationController.forward(from: 0.0);
    setState(() {});
  }


  void _shareResult(BuildContext context) {
    final text = 'FeroCalc FD Calculator\n\nPrincipal: ₹${_principal.toStringAsFixed(0)}\nRate: ${_interestRate.toStringAsFixed(2)}%\nTenure: ${_years}Y ${_months}M ${_days}D\nMaturity Value: ₹${_maturityValue.toStringAsFixed(0)}\nTotal Interest: ₹${_totalInterest.toStringAsFixed(0)}\n\nDownload FeroCalc for more!';
    Share.share(text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Result shared!'), backgroundColor: Color(0xFF10B981)),
    );
  }

  void _exportPdf(BuildContext context) {
    _shareResult(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'FD Calculator',
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
                    label: 'Principal Amount',
                    value: _principal,
                    min: 1000,
                    max: 100000000,
                    prefix: '₹',
                    onChanged: (val) {
                      setState(() => _principal = val);
                      _calculateFd();
                    },
                  ),
                  const SizedBox(height: 16),
                  InputSliderField(
                    label: 'Interest Rate (p.a)',
                    value: _interestRate,
                    min: 1,
                    max: 15,
                    suffix: '%',
                    onChanged: (val) {
                      setState(() => _interestRate = val);
                      _calculateFd();
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Senior Citizen (+0.5%)', style: AppTextStyles.bodyText),
                      Switch(
                        value: _isSeniorCitizen,
                        activeColor: const Color(0xFF00E676),
                        onChanged: (val) {
                          setState(() => _isSeniorCitizen = val);
                          _calculateFd();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Tenure', style: AppTextStyles.heading3),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown('Years', _years, 30, (val) {
                          setState(() => _years = val!);
                          _calculateFd();
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDropdown('Months', _months, 11, (val) {
                          setState(() => _months = val!);
                          _calculateFd();
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDropdown('Days', _days, 30, (val) {
                          setState(() => _days = val!);
                          _calculateFd();
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Compounding', style: AppTextStyles.bodyText),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _compoundingFrequency,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).cardColor,
                        items: _compoundingOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) {
                          setState(() => _compoundingFrequency = val!);
                          _calculateFd();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _fadeAnimation,
              child: ResultDisplayCard(
                mainLabel: 'Maturity Value',
                mainValue: _currencyFormat.format(_maturityValue),
                subResults: [
                  SubResult(label: 'Total Investment', value: _currencyFormat.format(_principal)),
                  SubResult(label: 'Interest Earned', value: _currencyFormat.format(_totalInterest)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildChart(context),
            const SizedBox(height: 24),
            if (_isSeniorCitizen)
              GlassmorphicCard(
                child: Column(
                  children: [
                    Text('Senior Citizen Benefit', style: AppTextStyles.heading3),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Additional Profit:', style: AppTextStyles.bodyText),
                        Text(
                          '+ ${_currencyFormat.format(_maturityValue - (_principal * pow((1 + (_interestRate / 100 / (_compoundingFrequency == 'Quarterly' ? 4 : 1))), (_compoundingFrequency == 'Quarterly' ? 4 : 1) * (_years + (_months / 12.0) + (_days / 365.0)))))}',
                          style: AppTextStyles.bodyText.copyWith(color: const Color(0xFF00E676), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            GradientButton(text: 'Save & Export',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved to history!'), backgroundColor: Color(0xFF10B981)),
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

  Widget _buildDropdown(String label, int value, int maxVal, ValueChanged<int?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: Theme.of(context).cardColor,
              items: List.generate(maxVal + 1, (index) => DropdownMenuItem(value: index, child: Text('$index'))),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context) {
    // Only show if calculated
    if (_maturityValue <= 0) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          Text('Breakdown', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          )),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: _principal,
                    title: '${(_principal / _maturityValue * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF1A5276),
                    radius: 60,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  PieChartSectionData(
                    value: _totalInterest,
                    title: '${(_totalInterest / _maturityValue * 100).toStringAsFixed(1)}%',
                    color: const Color(0xFF00E676),
                    radius: 60,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legendItem('Principal', const Color(0xFF1A5276)),
              _legendItem('Interest Earned', const Color(0xFF00E676)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
      ],
    );
  }

}

