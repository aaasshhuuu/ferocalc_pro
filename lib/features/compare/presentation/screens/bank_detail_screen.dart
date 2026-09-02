import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/data/bank_data.dart';
import '../../../../core/data/bank_rate_repository.dart';
import '../../../../core/models/bank.dart';
import '../../../../core/models/fd_rate.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../core/utils/responsive.dart';
import 'dart:math';

class BankDetailScreen extends StatelessWidget {
  final String bankName;

  const BankDetailScreen({Key? key, required this.bankName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Try new model first, fall back to legacy
    final legacyBank = BankDataService.getBankByName(bankName);
    final gold = const Color(0xFFC9A96E);

    if (legacyBank == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Bank Not Found'),
        body: const Center(child: Text('Bank details could not be found.')),
      );
    }

    // Find the new Bank model
    final bankId = bankName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final bank = BankRateRepository.getBankById(bankId);
    final allRates = bank != null ? BankRateRepository.getRatesForBank(bankId) : <FdRate>[];
    final regularRates = allRates.where((r) => r.customerType == CustomerType.regular).toList();
    final seniorRates = allRates.where((r) => r.customerType == CustomerType.seniorCitizen).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(title: legacyBank.name),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: Responsive.screenPadding(context),
            children: [
              _buildHeader(context, legacyBank, bank, gold).animate().fade(),
              const SizedBox(height: 24),
              _buildRateTable(context, 'FD Rates — Regular', regularRates, gold).animate().fade(delay: 100.ms),
              const SizedBox(height: 16),
              _buildRateTable(context, 'FD Rates — Senior Citizen', seniorRates, gold).animate().fade(delay: 200.ms),
              const SizedBox(height: 24),
              _buildDataDisclaimer(context).animate().fade(delay: 250.ms),
              const SizedBox(height: 24),
              _buildBankInfo(context, legacyBank, bank, gold).animate().fade(delay: 300.ms),
              const SizedBox(height: 24),
              _buildQuickActions(context, gold).animate().fade(delay: 400.ms),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BankInfo legacyBank, Bank? bank, Color gold) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: gold.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: gold, width: 2),
          ),
          child: Icon(Icons.account_balance, size: 40, color: gold),
        ),
        const SizedBox(height: 16),
        Text(
          legacyBank.name,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: gold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge(bank?.typeLabel ?? legacyBank.type.toUpperCase(), Theme.of(context).primaryColor),
            if (legacyBank.headquarters.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildBadge(legacyBank.headquarters, Colors.blueGrey),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Only show real data
        if (legacyBank.established.isNotEmpty || legacyBank.headquarters.isNotEmpty)
          Text(
            [
              if (legacyBank.established.isNotEmpty) 'Est. ${legacyBank.established}',
              if (legacyBank.headquarters.isNotEmpty) legacyBank.headquarters,
            ].join(' \u2022 '),
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
          ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRateTable(BuildContext context, String title, List<FdRate> rates, Color gold) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
              ),
              if (rates.isNotEmpty)
                VerificationBadge(status: rates.first.verificationStatus, rate: rates.first, bankName: bankName),
            ],
          ),
          const SizedBox(height: 16),
          if (rates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No rate data available', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Table(
                  border: TableBorder(
                    horizontalInside: BorderSide(color: Theme.of(context).dividerColor),
                    verticalInside: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.05)),
                      children: [
                        _buildTableCell(context, 'Tenure', isHeader: true),
                        _buildTableCell(context, 'Rate', isHeader: true),
                        _buildTableCell(context, 'Status', isHeader: true),
                      ],
                    ),
                    ...rates.map((rate) {
                      final maxRate = rates.map((r) => r.interestRate).reduce(max);
                      final isHighest = rate.interestRate == maxRate;
                      return TableRow(
                        decoration: isHighest ? BoxDecoration(color: gold.withOpacity(0.05)) : null,
                        children: [
                          _buildTableCell(context, rate.tenureDescription, isHighlight: isHighest, gold: gold),
                          _buildTableCell(context, '${rate.interestRate.toStringAsFixed(2)}% p.a.', isHighlight: isHighest, gold: gold),
                          _buildTableCell(context, 'Pending review', isHighlight: false),
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

  Widget _buildTableCell(BuildContext context, String text, {bool isHeader = false, bool isHighlight = false, Color? gold}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader || isHighlight ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 13 : 13,
          color: isHighlight ? gold : Theme.of(context).textTheme.bodyMedium?.color,
        ),
        textAlign: isHeader ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  Widget _buildDataDisclaimer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'All rates shown are unverified and may not reflect current bank rates. '
              'Verify with the bank directly before making financial decisions. '
              'Senior citizen premiums are approximate and subject to change.',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfo(BuildContext context, BankInfo legacyBank, Bank? bank, Color gold) {
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bank Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: 16),
          if (legacyBank.minFdAmount > 0)
            _buildInfoRow(context, Icons.money, 'Min FD Amount', '\u20B9${legacyBank.minFdAmount}'),
          if (legacyBank.maxFdTenure.isNotEmpty)
            _buildInfoRow(context, Icons.calendar_today, 'Max Tenure', legacyBank.maxFdTenure),
          if (legacyBank.customerCare.isNotEmpty)
            _buildInfoRow(context, Icons.support_agent, 'Customer Care', legacyBank.customerCare, color: gold),
          if (legacyBank.website.isNotEmpty)
            _buildInfoRow(context, Icons.language, 'Website', legacyBank.website, isLink: true, color: gold),
          if (legacyBank.totalBranches.isNotEmpty)
            _buildInfoRow(context, Icons.location_city, 'Branches', legacyBank.totalBranches),
          if (legacyBank.established.isNotEmpty)
            _buildInfoRow(context, Icons.history, 'Established', legacyBank.established),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, {bool isLink = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isLink ? (color ?? Theme.of(context).primaryColor) : Theme.of(context).textTheme.bodyMedium?.color,
                decoration: isLink ? TextDecoration.underline : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, Color gold) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () => context.go('/calculator/fd'),
          icon: const Icon(Icons.calculate),
          label: const Text('Calculate FD Returns'),
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => context.go('/calculator/rd'),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Calculate RD Returns'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/compare'),
          icon: const Icon(Icons.compare_arrows),
          label: const Text('Compare with Others'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
