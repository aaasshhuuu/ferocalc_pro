import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../config/themes/app_colors.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import '../../../../core/utils/financial_math.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';

/// Amortization Schedule Screen displaying month-wise loan repayment details
/// corresponding to the calculated EMI.
class AmortizationScheduleScreen extends StatelessWidget {
  const AmortizationScheduleScreen({
    Key? key,
    this.loanAmount = 1000000,
    this.interestRate = 8.5,
    this.tenureMonths = 120,
    this.isFlatRate = false,
  }) : super(key: key);

  final double loanAmount;
  final double interestRate;
  final int tenureMonths;
  final bool isFlatRate;

  static const double _colMonth = 55.0;
  static const double _colEmi = 95.0;
  static const double _colPrincipal = 100.0;
  static const double _colInterest = 100.0;
  static const double _colBalance = 110.0;
  static const double _rowPadH = 10.0;
  static const double _tableWidth = _colMonth +
      _colEmi +
      _colPrincipal +
      _colInterest +
      _colBalance +
      (_rowPadH * 2);

  static const String _disclaimerText =
      'Disclaimer: The amortization schedule is an estimate based on fixed-rate EMI and monthly compounding. '
      'Actual bank repayments may differ slightly based on processing dates, interest calculation frequency, and rounding practices.';

  Map<String, String> _getInputs({
    required double loanAmount,
    required double interestRate,
    required int tenureMonths,
    required bool isFlatRate,
    required NumberFormat currencyFormat,
  }) => {
    'Loan Amount': currencyFormat.format(loanAmount),
    'Interest Rate': '${interestRate.toStringAsFixed(2)}% p.a.',
    'Loan Tenure':
        '$tenureMonths Months (${(tenureMonths / 12).toStringAsFixed(tenureMonths % 12 == 0 ? 0 : 1)} Years)',
    'Loan Type': isFlatRate ? 'Flat Rate' : 'Reducing Balance',
  };

  Map<String, String> _getSummary({
    required double emi,
    required double totalInterest,
    required double totalPayment,
    required bool isFlatRate,
    required NumberFormat currencyFormat,
  }) => {
    'Monthly EMI': currencyFormat.format(emi),
    'Total Interest': currencyFormat.format(totalInterest),
    'Total Payment': currencyFormat.format(totalPayment),
    'Calculation Mode': isFlatRate ? 'Flat Rate' : 'Reducing Balance',
  };

  List<List<String>> _getScheduleRows({
    required List<Map<String, double>> schedule,
    required double loanAmount,
    required NumberFormat currencyFormat,
  }) {
    final List<List<String>> rows = [];
    double opening = loanAmount;
    for (final item in schedule) {
      final month = item['month']!.toInt();
      final emi = item['emi']!;
      final principal = item['principal']!;
      final interest = item['interest']!;
      final balance = item['balance']!;

      rows.add([
        '$month',
        currencyFormat.format(opening),
        currencyFormat.format(emi),
        currencyFormat.format(principal),
        currencyFormat.format(interest),
        balance <= 0.01 ? '₹0' : currencyFormat.format(balance),
      ]);

      opening = balance;
    }
    return rows;
  }

  static List<Map<String, double>> _generateFlatSchedule({
    required double principal,
    required double annualRate,
    required int months,
  }) {
    if (months <= 0 || principal <= 0) return [];
    final double emi = FinancialMath.calculateFlatRateEMI(
      principal: principal,
      annualRate: annualRate,
      months: months,
    );
    final double tYears = months / 12.0;
    final double totalInterest = (principal * annualRate * tYears) / 100.0;
    final double monthlyInterest = totalInterest / months;
    final double monthlyPrincipal = principal / months;

    final List<Map<String, double>> schedule = [];
    double balance = principal;

    for (int i = 1; i <= months; i++) {
      balance -= monthlyPrincipal;
      if (balance < 0 || (i == months && balance.abs() < 1.0)) {
        balance = 0;
      }
      schedule.add({
        'month': i.toDouble(),
        'emi': emi,
        'principal': monthlyPrincipal,
        'interest': monthlyInterest,
        'balance': balance,
      });
    }
    return schedule;
  }

  void _exportPdf({
    required BuildContext context,
    required double effectiveLoanAmount,
    required double effectiveRate,
    required int effectiveMonths,
    required bool isFlatRate,
    required double emi,
    required double totalInterest,
    required double totalPayment,
    required List<Map<String, double>> schedule,
    required NumberFormat currencyFormat,
  }) {
    CalculatorShareHelper.exportSchedulePdf(
      context: context,
      title: 'EMI Amortization Schedule',
      subtitle: isFlatRate
          ? 'Flat Rate Repayment Schedule'
          : 'Reducing Balance Repayment Schedule',
      scheduleSectionTitle: 'Repayment Schedule',
      inputs: _getInputs(
        loanAmount: effectiveLoanAmount,
        interestRate: effectiveRate,
        tenureMonths: effectiveMonths,
        isFlatRate: isFlatRate,
        currencyFormat: currencyFormat,
      ),
      summary: _getSummary(
        emi: emi,
        totalInterest: totalInterest,
        totalPayment: totalPayment,
        isFlatRate: isFlatRate,
        currencyFormat: currencyFormat,
      ),
      tableHeaders: const [
        'Month',
        'Opening Balance',
        'EMI',
        'Principal',
        'Interest',
        'Closing Balance',
      ],
      tableRows: _getScheduleRows(
        schedule: schedule,
        loanAmount: effectiveLoanAmount,
        currencyFormat: currencyFormat,
      ),
      disclaimer: _disclaimerText,
    );
  }

  void _shareSchedule({
    required BuildContext context,
    required double effectiveLoanAmount,
    required double effectiveRate,
    required int effectiveMonths,
    required bool isFlatRate,
    required double emi,
    required double totalInterest,
    required double totalPayment,
    required List<Map<String, double>> schedule,
    required NumberFormat currencyFormat,
  }) {
    _exportPdf(
      context: context,
      effectiveLoanAmount: effectiveLoanAmount,
      effectiveRate: effectiveRate,
      effectiveMonths: effectiveMonths,
      isFlatRate: isFlatRate,
      emi: emi,
      totalInterest: totalInterest,
      totalPayment: totalPayment,
      schedule: schedule,
      currencyFormat: currencyFormat,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLoanAmount = loanAmount > 0 ? loanAmount : 1000000.0;
    final effectiveRate = interestRate > 0 ? interestRate : 8.5;
    final effectiveMonths = tenureMonths > 0 ? tenureMonths : 120;

    final schedule = isFlatRate
        ? _generateFlatSchedule(
            principal: effectiveLoanAmount,
            annualRate: effectiveRate,
            months: effectiveMonths,
          )
        : FinancialMath.generateAmortizationSchedule(
            principal: effectiveLoanAmount,
            annualRate: effectiveRate,
            months: effectiveMonths,
          );

    final double emi = isFlatRate
        ? FinancialMath.calculateFlatRateEMI(
            principal: effectiveLoanAmount,
            annualRate: effectiveRate,
            months: effectiveMonths,
          )
        : FinancialMath.calculateEMI(
            principal: effectiveLoanAmount,
            annualRate: effectiveRate,
            months: effectiveMonths,
          );
    final double totalPayment = emi * effectiveMonths;
    final double totalInterest = totalPayment - effectiveLoanAmount;

    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Amortization Schedule',
        actions: [
          IconButton(
            key: const ValueKey('amortization_schedule_pdf_button'),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(
              context: context,
              effectiveLoanAmount: effectiveLoanAmount,
              effectiveRate: effectiveRate,
              effectiveMonths: effectiveMonths,
              isFlatRate: isFlatRate,
              emi: emi,
              totalInterest: totalInterest,
              totalPayment: totalPayment,
              schedule: schedule,
              currencyFormat: currencyFormat,
            ),
          ),
          IconButton(
            key: const ValueKey('amortization_schedule_share_button'),
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share Schedule',
            onPressed: () => _shareSchedule(
              context: context,
              effectiveLoanAmount: effectiveLoanAmount,
              effectiveRate: effectiveRate,
              effectiveMonths: effectiveMonths,
              isFlatRate: isFlatRate,
              emi: emi,
              totalInterest: totalInterest,
              totalPayment: totalPayment,
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
                  loanAmount: effectiveLoanAmount,
                  interestRate: effectiveRate,
                  tenureMonths: effectiveMonths,
                  isFlatRate: isFlatRate,
                  emi: emi,
                  totalInterest: totalInterest,
                  totalPayment: totalPayment,
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
    required double loanAmount,
    required double interestRate,
    required int tenureMonths,
    required bool isFlatRate,
    required double emi,
    required double totalInterest,
    required double totalPayment,
    required NumberFormat currencyFormat,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tenureYears = (tenureMonths / 12).toStringAsFixed(
      tenureMonths % 12 == 0 ? 0 : 1,
    );

    final principalPercent = totalPayment > 0
        ? (loanAmount / totalPayment * 100).clamp(0, 100).toDouble()
        : 100.0;
    final interestPercent = (100.0 - principalPercent).clamp(0, 100).toDouble();

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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Loan Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$tenureMonths Months ($tenureYears Yrs)',
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
                  label: 'Loan Amount',
                  value: currencyFormat.format(loanAmount),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Monthly EMI',
                  value: currencyFormat.format(emi),
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
                  label: 'Interest Rate',
                  value: '${interestRate.toStringAsFixed(2)}% p.a.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Total Interest',
                  value: currencyFormat.format(totalInterest),
                  valueColor: AppColors.gold,
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
                  label: 'Total Payment',
                  value: currencyFormat.format(totalPayment),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  context: context,
                  label: 'Loan Type',
                  value: isFlatRate ? 'Flat Rate' : 'Reducing Balance',
                  valueColor: AppColors.teal,
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
                    flex: max(1, principalPercent.round()),
                    child: Container(color: const Color(0xFF1A5276)),
                  ),
                  Expanded(
                    flex: max(1, interestPercent.round()),
                    child: Container(color: AppColors.gold),
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
                    'Principal: ${principalPercent.toStringAsFixed(1)}%',
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
                      color: AppColors.gold,
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Repayment Schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${schedule.length} Payments',
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
                  ...schedule.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final month = item['month']!.toInt();
                    final isYearStart = month == 1 || month % 12 == 1;
                    final yearNum = ((month - 1) ~/ 12) + 1;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isYearStart && schedule.length > 12)
                          _buildYearDivider(context, yearNum),
                        _buildTableRow(
                          context: context,
                          index: index,
                          month: month,
                          emi: item['emi']!,
                          principal: item['principal']!,
                          interest: item['interest']!,
                          balance: item['balance']!,
                          currencyFormat: currencyFormat,
                        ),
                      ],
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

  Widget _buildYearDivider(BuildContext context, int year) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.04),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined, size: 13, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            'Year $year',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      color: headerColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: _rowPadH),
      child: Row(
        children: [
          _buildCell('Month', width: _colMonth, isHeader: true, align: TextAlign.center),
          _buildCell('EMI', width: _colEmi, isHeader: true, align: TextAlign.right),
          _buildCell('Principal', width: _colPrincipal, isHeader: true, align: TextAlign.right),
          _buildCell('Interest', width: _colInterest, isHeader: true, align: TextAlign.right),
          _buildCell('Balance', width: _colBalance, isHeader: true, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required BuildContext context,
    required int index,
    required int month,
    required double emi,
    required double principal,
    required double interest,
    required double balance,
    required NumberFormat currencyFormat,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEven = index % 2 == 0;
    final rowColor = isEven
        ? Colors.transparent
        : (isDark
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.black.withValues(alpha: 0.02));

    return Container(
      key: ValueKey('amortization_row_$month'),
      color: rowColor,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: _rowPadH),
      child: Row(
        children: [
          _buildCell(
            '$month',
            width: _colMonth,
            align: TextAlign.center,
            key: ValueKey('amortization_period_$month'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          _buildCell(
            currencyFormat.format(emi),
            width: _colEmi,
            align: TextAlign.right,
            key: ValueKey('amortization_emi_$month'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          _buildCell(
            currencyFormat.format(principal),
            width: _colPrincipal,
            align: TextAlign.right,
            key: ValueKey('amortization_principal_$month'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.emerald,
            ),
          ),
          _buildCell(
            currencyFormat.format(interest),
            width: _colInterest,
            align: TextAlign.right,
            key: ValueKey('amortization_interest_$month'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.gold,
            ),
          ),
          _buildCell(
            balance <= 0.01 ? '₹0' : currencyFormat.format(balance),
            width: _colBalance,
            align: TextAlign.right,
            key: ValueKey('amortization_balance_$month'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: balance <= 0.01
                  ? AppColors.emerald
                  : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    String text, {
    required double width,
    bool isHeader = false,
    TextAlign align = TextAlign.left,
    TextStyle? style,
    Key? key,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        key: key,
        textAlign: align,
        style: style ??
            (isHeader
                ? const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  )
                : const TextStyle(
                    fontSize: 13,
                  )),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Disclaimer: The amortization schedule is an estimate based on fixed-rate EMI and monthly compounding. '
        'Actual bank repayments may differ slightly based on processing dates, interest calculation frequency, and rounding practices.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }
}
