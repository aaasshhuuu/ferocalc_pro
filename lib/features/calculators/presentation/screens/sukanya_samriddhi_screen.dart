import 'package:fincalc_pro/config/themes/app_text_styles.dart';
import 'package:fincalc_pro/core/utils/calculator_share_helper.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/core/utils/responsive.dart';
import 'package:fincalc_pro/core/widgets/calculator_purpose_card.dart';
import 'package:fincalc_pro/core/widgets/custom_app_bar.dart';
import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/gradient_button.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/features/history/presentation/helper/calculation_history_saver.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'ssy_schedule_screen.dart';

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
    final List<double> deposits = _isVariable ? _variableDeposits : List.filled(15, _fixedYearlyDeposit);
    final result = FinancialMath.calculateSSY(
      yearlyDeposits: deposits,
      annualRate: _interestRate,
      girlAge: _girlAge.toInt(),
    );
    _maturityValue = result['maturityValue']!;
    _totalInvestment = result['totalDeposit']!;
    _totalInterest = result['totalInterest']!;
    setState(() {});
  }

  void _calculateAndSave() {
    _calculateSsy();
    CalculationHistorySaver.save(
      context: context,
      calculatorId: 'sukanya_samriddhi',
      calculatorName: 'Sukanya Samriddhi (SSY)',
      inputs: _getInputs(),
      results: _getResults(),
      primaryResultLabel: 'Maturity Value (at Age ${(_girlAge + 21).toInt()})',
      primaryResultValue: _currencyFormat.format(_maturityValue),
      category: 'Investments',
    );
  }


  Map<String, String> _getInputs() => {
    'Girl Child Age': '${_girlAge.toInt()} Years',
    'Deposit Mode': _isVariable ? 'Variable' : 'Fixed',
    if (!_isVariable) 'Yearly Deposit': _currencyFormat.format(_fixedYearlyDeposit),
    'Interest Rate': '${_interestRate.toStringAsFixed(2)}% p.a.',
  };

  Map<String, String> _getResults() => {
    'Total Deposits': _currencyFormat.format(_totalInvestment),
    'Total Interest': _currencyFormat.format(_totalInterest),
    'Maturity Value (at Age ${(_girlAge + 21).toInt()})': _currencyFormat.format(_maturityValue),
  };

  void _shareResult(BuildContext context) {
    CalculatorShareHelper.shareText(
      context: context,
      title: 'Sukanya Samriddhi (SSY)',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _exportPdf(BuildContext context) {
    CalculatorShareHelper.exportPdf(
      context: context,
      title: 'Sukanya Samriddhi (SSY)',
      inputs: _getInputs(),
      results: _getResults(),
    );
  }

  void _openYearlySchedule(BuildContext context) {
    final List<double> deposits =
        _isVariable ? List.from(_variableDeposits) : List.filled(15, _fixedYearlyDeposit);
    final args = {
      'girlAge': _girlAge.toInt(),
      'interestRate': _interestRate,
      'yearlyDeposits': deposits,
      'isVariable': _isVariable,
    };

    try {
      context.push('/calculator/sukanya/schedule', extra: args);
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SsyScheduleScreen(
            girlAge: _girlAge.toInt(),
            interestRate: _interestRate,
            yearlyDeposits: deposits,
            isVariable: _isVariable,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Sukanya Samriddhi (SSY)',
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
            const SizedBox(height: 16),
            GradientButton(
              key: const ValueKey('calculate_button'),
              text: 'Calculate',
              onPressed: _calculateAndSave,
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
            GradientButton(
              key: const ValueKey('view_ssy_schedule_button'),
              text: 'View Year-wise Schedule',
              onPressed: () => _openYearlySchedule(context),
            ),
            const SizedBox(height: 24),
            const CalculatorPurposeCard(calculatorId: 'sukanya'),
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

