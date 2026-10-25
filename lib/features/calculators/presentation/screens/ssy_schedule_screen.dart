import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../config/themes/app_colors.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import '../../../../core/utils/financial_math.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';

/// Sukanya Samriddhi Yojana (SSY) Year-wise Schedule Screen
/// displaying annual deposits, interest accumulation, and closing balances
/// until maturity at girl child age 21.
class SsyScheduleScreen extends StatelessWidget {
  const SsyScheduleScreen({
    Key? key,
    this.girlAge = 0,
    this.interestRate = 8.2,
    this.yearlyDeposits = const [],
    this.isVariable = false,
  }) : super(key: key);

  final int girlAge;
  final double interestRate;
  final List<double> yearlyDeposits;
  final bool isVariable;

  static const double _colYear = 50.0;
  static const double _colAge = 50.0;
  static const double _colOpening = 105.0;
  static const double _colDeposit = 95.0;
  static const double _colInterest = 95.0;
  static const double _colClosing = 110.0;
  static const double _rowPadH = 10.0;
  static const double _tableWidth = _colYear +
      _colAge +
      _colOpening +
      _colDeposit +
      _colInterest +
      _colClosing +
      (_rowPadH * 2);

  Map<String, String> _getInputs({
    required int effectiveAge,
    required double effectiveRate,
    required bool isVariable,
    required List<double> effectiveDeposits,
    required NumberFormat currencyFormat,
  }) => {
    'Girl Child Age': '$effectiveAge Years',
    'Deposit Mode': isVariable ? 'Variable' : 'Fixed',
    if (!isVariable && effectiveDeposits.isNotEmpty)
      'Yearly Deposit': currencyFormat.format(effectiveDeposits.first),
    'Interest Rate': '${effectiveRate.toStringAsFixed(2)}% p.a.',
    'Deposit Period': '15 Years',
  };

  Map<String, String> _getSummary({
    required double totalDeposit,
    required double totalInterest,
    required double maturityValue,
    required int maturityYears,
    required NumberFormat currencyFormat,
  }) => {
    'Total Deposits': currencyFormat.format(totalDeposit),
    'Total Interest': currencyFormat.format(totalInterest),
    'Maturity Value (at Age 21)': currencyFormat.format(maturityValue),
    'Maturity Period': '$maturityYears Years',
  };

  List<List<String>> _getScheduleRows({
    required List<Map<String, double>> schedule,
    required NumberFormat currencyFormat,
  }) => schedule.map((row) => [
    'Yr ${(row['year'] ?? 0).toInt()}',
    '${(row['age'] ?? 0).toInt()} Yrs',
    currencyFormat.format(row['openingBalance'] ?? 0),
    currencyFormat.format(row['deposit'] ?? 0),
    currencyFormat.format(row['interest'] ?? 0),
    currencyFormat.format(row['closingBalance'] ?? 0),
  ],).toList();

  void _exportPdf({
    required BuildContext context,
    required int effectiveAge,
    required double effectiveRate,
    required bool isVariable,
    required List<double> effectiveDeposits,
    required double totalDeposit,
    required double totalInterest,
    required double maturityValue,
    required int maturityYears,
    required List<Map<String, double>> schedule,
    required NumberFormat currencyFormat,
  }) {
    CalculatorShareHelper.exportSchedulePdf(
      context: context,
      title: 'Sukanya Samriddhi (SSY)',
      subtitle: 'Year-wise Deposit & Interest Schedule',
      inputs: _getInputs(
        effectiveAge: effectiveAge,
        effectiveRate: effectiveRate,
        isVariable: isVariable,
        effectiveDeposits: effectiveDeposits,
        currencyFormat: currencyFormat,
      ),
      summary: _getSummary(
        totalDeposit: totalDeposit,
        totalInterest: totalInterest,
        maturityValue: maturityValue,
        maturityYears: maturityYears,
        currencyFormat: currencyFormat,
      ),
      tableHeaders: const [
        'Year',
        'Age',
        'Opening Balance',
        'Deposit',
        'Interest Earned',
        'Closing Balance',
      ],
      tableRows: _getScheduleRows(
        schedule: schedule,
        currencyFormat: currencyFormat,
      ),
    );
  }

  void _shareSchedule({
    required BuildContext context,
    required int effectiveAge,
    required double effectiveRate,
    required bool isVariable,
    required List<double> effectiveDeposits,
    required double totalDeposit,
    required double totalInterest,
    required double maturityValue,
    required int maturityYears,
    required List<Map<String, double>> schedule,
    required NumberFormat currencyFormat,
  }) {
    _exportPdf(
      context: context,
      effectiveAge: effectiveAge,
      effectiveRate: effectiveRate,
      isVariable: isVariable,
      effectiveDeposits: effectiveDeposits,
      totalDeposit: totalDeposit,
      totalInterest: totalInterest,
      maturityValue: maturityValue,
      maturityYears: maturityYears,
      schedule: schedule,
      currencyFormat: currencyFormat,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAge = girlAge.clamp(0, 10);
    final effectiveRate = interestRate > 0 ? interestRate : 8.2;
    final effectiveDeposits = yearlyDeposits.isNotEmpty
        ? yearlyDeposits
        : List.filled(15, 150000.0);

    final schedule = FinancialMath.generateSSYSchedule(
      yearlyDeposits: effectiveDeposits,
      annualRate: effectiveRate,
      girlAge: effectiveAge,
    );

    final ssyResult = FinancialMath.calculateSSY(
      yearlyDeposits: effectiveDeposits,
      annualRate: effectiveRate,
      girlAge: effectiveAge,
    );

    final totalDeposit = ssyResult['totalDeposit'] ?? 0.0;
    final totalInterest = ssyResult['totalInterest'] ?? 0.0;
    final maturityValue = ssyResult['maturityValue'] ?? 0.0;
    final maturityYears = 21 - effectiveAge;

    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'SSY Year-wise Schedule',
        actions: [
          IconButton(
            key: const ValueKey('ssy_schedule_pdf_button'),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(
              context: context,
              effectiveAge: effectiveAge,
              effectiveRate: effectiveRate,
              isVariable: isVariable,
              effectiveDeposits: effectiveDeposits,
              totalDeposit: totalDeposit,
              totalInterest: totalInterest,
              maturityValue: maturityValue,
              maturityYears: maturityYears,
              schedule: schedule,
              currencyFormat: currencyFormat,
            ),
          ),
          IconButton(
            key: const ValueKey('ssy_schedule_share_button'),
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share Schedule',
            onPressed: () => _shareSchedule(
              context: context,
              effectiveAge: effectiveAge,
              effectiveRate: effectiveRate,
              isVariable: isVariable,
              effectiveDeposits: effectiveDeposits,
              totalDeposit: totalDeposit,
              totalInterest: totalInterest,
              maturityValue: maturityValue,
              maturityYears: maturityYears,
              schedule: schedule,
              currencyFormat: currencyFormat,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: Responsive.screenPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryCard(
                  context: context,
                  girlAge: effectiveAge,
                  maturityYears: maturityYears,
                  interestRate: effectiveRate,
                  isVariable: isVariable,
                  totalDeposit: totalDeposit,
                  totalInterest: totalInterest,
                  maturityValue: maturityValue,
                  currencyFormat: currencyFormat,
                ),
                const SizedBox(height: 20),
                _buildScheduleSection(
                  context: context,
                  schedule: schedule,
                  currencyFormat: currencyFormat,
                ),
                const SizedBox(height: 20),
                _buildDisclaimer(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required int girlAge,
    required int maturityYears,
    required double interestRate,
    required bool isVariable,
    required double totalDeposit,
    required double totalInterest,
    required double maturityValue,
    required NumberFormat currencyFormat,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final depositPercent = maturityValue > 0
        ? (totalDeposit / maturityValue * 100).clamp(0, 100).toDouble()
        : 100.0;
    final interestPercent = (100.0 - depositPercent).clamp(0, 100).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Account Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Matures at Age 21 ($maturityYears Yrs)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Girl Child Age',
                  value: '$girlAge Years',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Deposit Mode',
                  value: isVariable ? 'Variable' : 'Fixed',
                  valueColor: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Interest Rate',
                  value: '${interestRate.toStringAsFixed(2)}% p.a.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Deposit Period',
                  value: '15 Years',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Total Deposits',
                  value: currencyFormat.format(totalDeposit),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Total Interest',
                  value: currencyFormat.format(totalInterest),
                  valueColor: AppColors.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Maturity Value (at Age 21)',
                  value: currencyFormat.format(maturityValue),
                  valueColor: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Ratio progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: max(1, depositPercent.round()),
                    child: Container(color: const Color(0xFF1A5276)),
                  ),
                  Expanded(
                    flex: max(1, interestPercent.round()),
                    child: Container(color: AppColors.emerald),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A5276),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Deposits: ${depositPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.emerald,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Interest: ${interestPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection({
    required BuildContext context,
    required List<Map<String, double>> schedule,
    required NumberFormat currencyFormat,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  'Year-wise Schedule',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${schedule.length} Years',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Swipe horizontally to view all columns',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // Horizontal scrolling table to avoid RenderFlex overflow on narrow screens
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: _tableWidth,
              child: Column(
                children: [
                  _buildTableHeader(context),
                  const Divider(height: 1),
                  ...schedule.map((item) {
                    final year = item['year']!.toInt();
                    final age = item['age']!.toInt();
                    final opening = item['openingBalance']!;
                    final deposit = item['deposit']!;
                    final interest = item['interest']!;
                    final closing = item['closingBalance']!;

                    return _buildTableRow(
                      context: context,
                      year: year,
                      age: age,
                      opening: opening,
                      deposit: deposit,
                      interest: interest,
                      closing: closing,
                      currencyFormat: currencyFormat,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _rowPadH,
        vertical: 10,
      ),
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
      child: Row(
        children: [
          _buildHeaderCell(context, 'Yr', _colYear),
          _buildHeaderCell(context, 'Age', _colAge),
          _buildHeaderCell(
            context,
            'Opening (₹)',
            _colOpening,
            align: TextAlign.right,
          ),
          _buildHeaderCell(
            context,
            'Deposit (₹)',
            _colDeposit,
            align: TextAlign.right,
          ),
          _buildHeaderCell(
            context,
            'Interest (₹)',
            _colInterest,
            align: TextAlign.right,
          ),
          _buildHeaderCell(
            context,
            'Closing (₹)',
            _colClosing,
            align: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    BuildContext context,
    String text,
    double width, {
    TextAlign align = TextAlign.left,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }

  Widget _buildTableRow({
    required BuildContext context,
    required int year,
    required int age,
    required double opening,
    required double deposit,
    required double interest,
    required double closing,
    required NumberFormat currencyFormat,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEven = year % 2 == 0;
    final isDepositPeriod = year <= 15;

    final rowBg = isEven
        ? (isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.015))
        : Colors.transparent;

    return Container(
      key: ValueKey('ssy_row_$year'),
      padding: const EdgeInsets.symmetric(
        horizontal: _rowPadH,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Year
          SizedBox(
            width: _colYear,
            child: Text(
              'Y$year',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          // Age
          SizedBox(
            width: _colAge,
            child: Text(
              '$age',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          // Opening balance
          SizedBox(
            width: _colOpening,
            child: Text(
              currencyFormat.format(opening),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          // Deposit
          SizedBox(
            width: _colDeposit,
            child: Text(
              deposit > 0 ? currencyFormat.format(deposit) : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isDepositPeriod ? FontWeight.w600 : FontWeight.normal,
                color: deposit > 0
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          // Interest
          SizedBox(
            width: _colInterest,
            child: Text(
              currencyFormat.format(interest),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.emerald,
              ),
            ),
          ),
          // Closing balance
          SizedBox(
            width: _colClosing,
            child: Text(
              currencyFormat.format(closing),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.amber,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Disclaimer: SSY interest rate is notified quarterly by the Government of India. Calculations assume the current rate remains constant over the investment tenure. Account matures when the girl child turns 21 years old.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.amber,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
