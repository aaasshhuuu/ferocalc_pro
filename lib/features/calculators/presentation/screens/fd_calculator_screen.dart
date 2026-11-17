import 'dart:math';

import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/core/widgets/calculator_purpose_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/features/history/presentation/helper/calculation_history_saver.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/calculator_share_helper.dart';
import '../../../../core/utils/responsive.dart';

class FdCalculatorScreen extends StatefulWidget {
  const FdCalculatorScreen({
    Key? key,
    this.initialPrincipal,
    this.initialInterestRate,
    this.initialYears,
    this.initialMonths,
    this.initialDays,
    this.initialIsSeniorCitizen,
    this.appliedBankName,
    this.appliedSourceUrl,
    this.appliedVerifiedAt,
    this.appliedCompoundingFrequency,
  }) : super(key: key);

  final double? initialPrincipal;
  final double? initialInterestRate;
  final int? initialYears;
  final int? initialMonths;
  final int? initialDays;
  final bool? initialIsSeniorCitizen;
  final String? appliedBankName;
  final String? appliedSourceUrl;
  final DateTime? appliedVerifiedAt;
  final String? appliedCompoundingFrequency;

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
  bool _isSimpleInterest = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final List<String> _compoundingOptions = ['Monthly', 'Quarterly', 'Half-Yearly', 'Yearly'];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrincipal != null && widget.initialPrincipal! > 0) {
      _principal = widget.initialPrincipal!;
    }
    if (widget.initialInterestRate != null && widget.initialInterestRate! > 0) {
      _interestRate = widget.initialInterestRate!;
    }
    if (widget.initialYears != null && widget.initialYears! >= 0) {
      _years = widget.initialYears!;
    }
    if (widget.initialMonths != null && widget.initialMonths! >= 0) {
      _months = widget.initialMonths!;
    }
    if (widget.initialDays != null && widget.initialDays! >= 0) {
      _days = widget.initialDays!;
    }
    if (widget.initialIsSeniorCitizen != null) {
      _isSeniorCitizen = widget.initialIsSeniorCitizen!;
    }
    if (widget.appliedCompoundingFrequency != null &&
        _compoundingOptions.contains(widget.appliedCompoundingFrequency)) {
      _compoundingFrequency = widget.appliedCompoundingFrequency!;
    }

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _calculateFd();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int _getCompoundingFrequency() {
    switch (_compoundingFrequency) {
      case 'Monthly': return 12;
      case 'Quarterly': return 4;
      case 'Half-Yearly': return 2;
      case 'Yearly': return 1;
      default: return 4;
    }
  }

  void _calculateFd() {
    final double years = FinancialMath.combinedTenureToYears(
      years: _years.toInt(),
      months: _months.toInt(),
      days: _days.toInt(),
    );
    double effectiveRate = _interestRate;
    if (widget.appliedBankName != null) {
      if (widget.initialIsSeniorCitizen == true) {
        effectiveRate = _isSeniorCitizen ? _interestRate : _interestRate - 0.5;
      } else {
        effectiveRate = _isSeniorCitizen ? _interestRate + 0.5 : _interestRate;
      }
    } else {
      effectiveRate = _isSeniorCitizen ? _interestRate + 0.5 : _interestRate;
    }
    if (_isSimpleInterest) {
      _totalInterest = FinancialMath.calculateSimpleInterest(
        principal: _principal,
        annualRate: effectiveRate,
        time: years,
        timeUnit: TimeUnit.years,
      );
      _maturityValue = _principal + _totalInterest;
    } else {
      final int n = _getCompoundingFrequency();
      _maturityValue = FinancialMath.calculateFDMaturity(
        principal: _principal,
        annualRate: effectiveRate,
        years: years,
        compoundingFrequency: n,
      );
      _totalInterest = _maturityValue - _principal;
    }
    _animationController.forward(from: 0.0);
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateFd();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'fd',
      calculatorName: 'FD Calculator',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Maturity Value',
      primaryResultValue: _currencyFormat.format(_maturityValue),
      category: 'Deposits',
      rawInputs: {
        'principal': _principal,
        'interestRate': _interestRate,
        'years': _years,
        'months': _months,
        'days': _days,
        'isSeniorCitizen': _isSeniorCitizen,
        'compoundingFrequency': _compoundingFrequency,
        'isSimpleInterest': _isSimpleInterest,
      },
    );
  }

  Map<String, String> _getInputs() => {
    'Deposit Amount': _currencyFormat.format(_principal),
    'Interest Rate': '${_interestRate.toStringAsFixed(2)}% p.a.',
    'Tenure': '${_years}Y ${_months}M ${_days}D',
    'Deposit Type': _isSimpleInterest ? 'Non-Cumulative (Simple Interest)' : 'Cumulative (Compound Interest)',
    'Compounding Frequency': _isSimpleInterest ? 'Simple Interest (N/A)' : _compoundingFrequency,
    'Senior Citizen': _isSeniorCitizen ? 'Yes (+0.5%)' : 'No',
  };

  Map<String, String> _getResults() => {
    'Maturity Value': _currencyFormat.format(_maturityValue),
    'Total Interest': _currencyFormat.format(_totalInterest),
    'Total Investment': _currencyFormat.format(_principal),
    'Deposit Scheme': _isSimpleInterest ? 'Non-Cumulative (Simple Interest)' : 'Cumulative (Compounding)',
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'FD Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'FD Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'FD Calculator',
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(context),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share Calculation',
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
            if (widget.appliedBankName != null) ...[
              _buildAppliedRateBanner(context),
            ],
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
                      Expanded(
                        child: Text('Senior Citizen (+0.5%)', style: AppTextStyles.bodyText),
                      ),
                      Semantics(
                        label: 'Senior Citizen rate premium',
                        toggled: _isSeniorCitizen,
                        child: Switch(
                          value: _isSeniorCitizen,
                          activeThumbColor: const Color(0xFF00E676),
                          onChanged: (val) {
                            setState(() => _isSeniorCitizen = val);
                            _calculateFd();
                          },
                        ),
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text('Deposit Type', style: AppTextStyles.bodyText),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            key: const ValueKey('fd_type_cumulative'),
                            label: const Text('Cumulative'),
                            selected: !_isSimpleInterest,
                            onSelected: (val) {
                              setState(() => _isSimpleInterest = false);
                              _calculateFd();
                            },
                          ),
                          ChoiceChip(
                            key: const ValueKey('fd_type_simple'),
                            label: const Text('Non-Cumulative (SI)'),
                            selected: _isSimpleInterest,
                            onSelected: (val) {
                              setState(() => _isSimpleInterest = true);
                              _calculateFd();
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
                      _isSimpleInterest
                          ? 'Non-cumulative deposit calculates Simple Interest (standard for tenures < 180 days).'
                          : 'Cumulative deposit reinvests interest with periodic compounding.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Compounding', style: AppTextStyles.bodyText),
                  const SizedBox(height: 8),
                  if (!_isSimpleInterest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const ValueKey('fd_compounding_dropdown'),
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
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Simple Interest (No compounding / Payout)',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color),
                      ),
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
                mainLabel: 'Maturity Value',
                mainValue: _currencyFormat.format(_maturityValue),
                subResults: [
                  SubResult(label: 'Total Investment', value: _currencyFormat.format(_principal)),
                  SubResult(label: 'Interest Earned', value: _currencyFormat.format(_totalInterest)),
                  SubResult(label: 'Deposit Scheme', value: _isSimpleInterest ? 'Non-Cumulative (Simple Interest)' : 'Cumulative (Compound Interest)'),
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
                          '+ ${_currencyFormat.format(_maturityValue - (_principal * pow(1 + (_interestRate / 100 / (_compoundingFrequency == 'Quarterly' ? 4 : 1)), (_compoundingFrequency == 'Quarterly' ? 4 : 1) * (_years + (_months / 12.0) + (_days / 365.0)))))}',
                          style: AppTextStyles.bodyText.copyWith(color: const Color(0xFF00E676), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            GradientButton(
              key: const ValueKey('fd_save_export_button'),
              text: 'Save & Export',
              onPressed: () {
                _calculateAndSave();
                _exportPdf(context);
              },
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'fd'),
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
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Semantics(
            label: '$label: $value',
            button: true,
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
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context) {
    // Only show if calculated
    if (_maturityValue <= 0) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final principalPct = (_principal / _maturityValue * 100).toStringAsFixed(1);
    final interestPct = (_totalInterest / _maturityValue * 100).toStringAsFixed(1);
    
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
          ),),
          const SizedBox(height: 16),
          Semantics(
            label: 'Deposit breakdown chart: Principal $principalPct percent, Interest Earned $interestPct percent',
            child: SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: _principal,
                      title: '$principalPct%',
                      color: const Color(0xFF1A5276),
                      radius: 60,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: _totalInterest,
                      title: '$interestPct%',
                      color: const Color(0xFF00E676),
                      radius: 60,
                      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
      ],
    );
  }

  Widget _buildAppliedRateBanner(BuildContext context) {
    const gold = Color(0xFFC9A96E);
    final isModified = widget.initialInterestRate != null &&
        (_interestRate != widget.initialInterestRate);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2218),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verified Rate Applied: ${widget.appliedBankName}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              if (isModified)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _interestRate = widget.initialInterestRate!;
                      if (widget.initialIsSeniorCitizen != null) {
                        _isSeniorCitizen = widget.initialIsSeniorCitizen!;
                      }
                      _calculateFd();
                    });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('Reset Rate', style: TextStyle(color: gold, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Official bank rate of ${widget.initialInterestRate?.toStringAsFixed(2)}% p.a. pre-loaded from ${widget.appliedBankName}. You may adjust assumptions freely; your changes will not affect the official bank record.',
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
          if (widget.appliedSourceUrl != null && widget.appliedSourceUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final uri = Uri.tryParse(widget.appliedSourceUrl!);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_new, size: 12, color: gold),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Official Source: ${widget.appliedSourceUrl}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: gold,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

}
