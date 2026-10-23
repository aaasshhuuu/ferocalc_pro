import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import '../../../../core/utils/financial_math.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/calculator_purpose_card.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/widgets/input_slider_field.dart';
import '../../../../core/widgets/result_display_card.dart';
import '../../../history/presentation/helper/calculation_history_saver.dart';

class SimpleInterestCalculatorScreen extends StatefulWidget {
  const SimpleInterestCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<SimpleInterestCalculatorScreen> createState() => _SimpleInterestCalculatorScreenState();
}

class _SimpleInterestCalculatorScreenState extends State<SimpleInterestCalculatorScreen> {
  double _principal = 100000;
  double _interestRate = 8.0;
  double _time = 3.0;
  TimeUnit _timeUnit = TimeUnit.years;

  double _simpleInterest = 0;
  double _totalAmount = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    final summary = FinancialMath.calculateSimpleInterestSummary(
      principal: _principal,
      annualRate: _interestRate,
      time: _time,
      timeUnit: _timeUnit,
    );

    setState(() {
      _simpleInterest = summary['interest'] ?? 0.0;
      _totalAmount = summary['totalAmount'] ?? 0.0;
    });
  }

  void _calculateAndSave() {
    _calculate();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'simple_interest',
      calculatorName: 'Simple Interest',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Total Amount',
      primaryResultValue: _currencyFormat.format(_totalAmount),
      category: 'General Interest',
      rawInputs: {
        'principal': _principal,
        'interestRate': _interestRate,
        'time': _time,
        'timeUnit': _timeUnit.name,
      },
    );
  }

  Map<String, String> _getInputs() {
    final timeStr = _time == _time.truncateToDouble()
        ? _time.toStringAsFixed(0)
        : _time.toStringAsFixed(2);
    return {
      'Principal Amount': _currencyFormat.format(_principal),
      'Interest Rate': '${_interestRate.toStringAsFixed(2)}% p.a.',
      'Time Period': '$timeStr ${_timeUnit.label}',
    };
  }

  Map<String, String> _getResults() => {
    'Principal Amount': _currencyFormat.format(_principal),
    'Simple Interest': _currencyFormat.format(_simpleInterest),
    'Total Amount': _currencyFormat.format(_totalAmount),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Simple Interest Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Simple Interest Calculator',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  double get _maxTimeForUnit {
    switch (_timeUnit) {
      case TimeUnit.years:
        return 50.0;
      case TimeUnit.quarters:
        return 200.0;
      case TimeUnit.months:
        return 360.0;
      case TimeUnit.days:
        return 1825.0;
    }
  }

  void _onTimeUnitChanged(TimeUnit unit) {
    if (_timeUnit == unit) return;
    setState(() {
      // Intelligently convert the current time to the new unit
      final years = FinancialMath.convertTimeToYears(time: _time, timeUnit: _timeUnit);
      _timeUnit = unit;
      switch (unit) {
        case TimeUnit.years:
          _time = (years.clamp(0.0, 50.0) * 100).round() / 100.0;
          if (_time == 0) _time = 1.0;
          break;
        case TimeUnit.quarters:
          _time = (years * 4.0).clamp(1.0, 200.0).roundToDouble();
          break;
        case TimeUnit.months:
          _time = (years * 12.0).clamp(1.0, 360.0).roundToDouble();
          break;
        case TimeUnit.days:
          _time = (years * 365.0).clamp(1.0, 1825.0).roundToDouble();
          break;
      }
    });
    _calculate();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color gold = Color(0xFFC9A96E);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Simple Interest',
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(context),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share',
            onPressed: () => _shareResult(context),
          ),
          const SizedBox(width: 8),
        ],
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
                      InputSliderField(
                        label: 'Principal Amount',
                        value: _principal,
                        min: 0,
                        max: 10000000,
                        prefix: '₹',
                        onChanged: (val) {
                          setState(() => _principal = val);
                          _calculate();
                        },
                      ),
                      const SizedBox(height: 16),
                      InputSliderField(
                        label: 'Interest Rate (p.a.)',
                        value: _interestRate,
                        min: 0,
                        max: 50,
                        suffix: '%',
                        onChanged: (val) {
                          setState(() => _interestRate = val);
                          _calculate();
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Time Unit',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: TimeUnit.values.map((unit) {
                          final isSelected = _timeUnit == unit;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: ElevatedButton(
                                key: ValueKey('time_unit_${unit.name}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? gold
                                      : (isDark ? Colors.white10 : Colors.grey[200]),
                                  foregroundColor: isSelected
                                      ? Colors.black
                                      : (isDark ? Colors.white70 : Colors.black87),
                                  elevation: isSelected ? 2 : 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                                ),
                                onPressed: () => _onTimeUnitChanged(unit),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    unit.label,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      InputSliderField(
                        label: 'Time Period (${_timeUnit.label})',
                        value: _time,
                        min: 0,
                        max: _maxTimeForUnit,
                        suffix: ' ${_timeUnit.shortLabel}',
                        onChanged: (val) {
                          setState(() => _time = val);
                          _calculate();
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
                ResultDisplayCard(
                  mainLabel: 'Total Amount',
                  mainValue: _currencyFormat.format(_totalAmount),
                  subResults: [
                    SubResult(
                      label: 'Principal Amount',
                      value: _currencyFormat.format(_principal),
                    ),
                    SubResult(
                      label: 'Simple Interest',
                      value: _currencyFormat.format(_simpleInterest),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBreakdownChart(context),
                const SizedBox(height: 16),
                _buildFormulaCard(context),
                const SizedBox(height: 16),
                const CalculatorPurposeCard(calculatorId: 'simple_interest'),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormulaCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.functions, size: 18, color: Color(0xFFC9A96E)),
              const SizedBox(width: 8),
              Text(
                'Formula',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Simple Interest = P × R × T / 100\n• Total Amount = P + Simple Interest',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownChart(BuildContext context) {
    if (_totalAmount <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final principalPct = _totalAmount > 0 ? (_principal / _totalAmount) * 100 : 0.0;
    final interestPct = _totalAmount > 0 ? (_simpleInterest / _totalAmount) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        children: [
          Text(
            'Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: _principal > 0 ? _principal : 0.001,
                    title: '${principalPct.toStringAsFixed(1)}%',
                    color: const Color(0xFF1A5276),
                    radius: 50,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PieChartSectionData(
                    value: _simpleInterest > 0 ? _simpleInterest : 0.001,
                    title: '${interestPct.toStringAsFixed(1)}%',
                    color: const Color(0xFF00E676),
                    radius: 50,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _legendItem('Principal', const Color(0xFF1A5276)),
              _legendItem('Simple Interest', const Color(0xFF00E676)),
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
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}
