import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/data/bank_data.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/utils/responsive.dart';
import 'dart:math';

class BankDetailScreen extends StatelessWidget {
  final String bankName;

  const BankDetailScreen({Key? key, required this.bankName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bank = BankDataService.getBankByName(bankName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = const Color(0xFFC9A96E);
    final emerald = const Color(0xFF10B981);
    final teal = const Color(0xFF00B4D8);

    if (bank == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Bank Not Found'),
        body: const Center(child: Text('Bank details could not be found.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(title: bank.name),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: Responsive.screenPadding(context),
            children: [
              _buildHeader(context, bank, gold).animate().fade(),
              const SizedBox(height: 24),
              _buildRatesSection(context, bank, gold, emerald).animate().fade(delay: 100.ms),
              const SizedBox(height: 24),
              _buildSavingsSection(context, bank, teal).animate().fade(delay: 200.ms),
              const SizedBox(height: 24),
              _buildOffersSection(context, gold).animate().fade(delay: 300.ms),
              const SizedBox(height: 24),
              _buildFeaturesSection(context, teal).animate().fade(),
              const SizedBox(height: 24),
              _buildQuickInfoSection(context, bank, gold).animate().fade(),
              const SizedBox(height: 32),
              _buildQuickActions(context, gold).animate().fade(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BankInfo bank, Color gold) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: gold, width: 2),
          ),
          child: Icon(Icons.account_balance, size: 40, color: gold),
        ),
        const SizedBox(height: 16),
        Text(
          bank.name,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: gold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge(bank.type.toUpperCase(), Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            _buildBadge(bank.country, Colors.blueGrey),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Established: 1990 • Headquarters: ${bank.country}',
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
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRatesSection(BuildContext context, BankInfo bank, Color gold, Color emerald) {
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fixed Deposit (FD) Rates',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Senior Citizen Extra: +0.50%', style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRatesTable(context, bank.fdRates, gold),
          const SizedBox(height: 24),
          Text(
            'Recurring Deposit (RD) Rates',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 16),
          _buildRatesTable(context, bank.rdRates, gold),
        ],
      ),
    );
  }

  Widget _buildRatesTable(BuildContext context, Map<String, double> rates, Color gold) {
    if (rates.isEmpty) return const Text('Rates not available');

    final maxRate = rates.values.reduce(max);
    
    // Sort duration keys logically if possible. For simplicity, just use entries.
    final entries = rates.entries.toList();

    return Container(
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
                _buildTableCell(context, 'Duration', isHeader: true),
                _buildTableCell(context, 'Rate', isHeader: true),
                _buildTableCell(context, 'Senior Citizen', isHeader: true),
              ],
            ),
            ...entries.map((e) {
              final isHighest = e.value == maxRate;
              return TableRow(
                decoration: isHighest ? BoxDecoration(color: gold.withOpacity(0.05)) : null,
                children: [
                  _buildTableCell(context, e.key, isHighlight: isHighest, gold: gold),
                  _buildTableCell(context, '${e.value.toStringAsFixed(2)}%', isHighlight: isHighest, gold: gold),
                  _buildTableCell(context, '${(e.value + 0.5).toStringAsFixed(2)}%', isHighlight: isHighest, gold: gold),
                ],
              );
            }).toList(),
          ],
        ),
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
          color: isHighlight ? gold : Theme.of(context).textTheme.bodyMedium?.color,
        ),
        textAlign: isHeader ? TextAlign.center : TextAlign.left,
      ),
    );
  }

  Widget _buildSavingsSection(BuildContext context, BankInfo bank, Color teal) {
    if (bank.savingsRate == null) return const SizedBox.shrink();
    return GlassmorphicCard(
      child: Row(
        children: [
          Icon(Icons.savings, size: 32, color: teal),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Savings Account Rate', style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color)),
                Text('${bank.savingsRate!.toStringAsFixed(2)}% p.a.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: teal)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersSection(BuildContext context, Color gold) {
    final offers = [
      'Extra 0.50% for Senior Citizens across all tenures.',
      'Special FD: 7.25% for 444 days.',
      'Zero penalty on premature withdrawal for FDs above 1 Lakh.',
    ];
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Offers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: 12),
          ...offers.map((offer) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, size: 20, color: gold),
                const SizedBox(width: 8),
                Expanded(child: Text(offer, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.4))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, Color teal) {
    final features = [
      'Online FD Booking',
      'Auto-Renewal',
      'Loan against FD',
      'Tax Saver FD',
      'Flexible Payouts',
      'Premature Withdrawal',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Features', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: features.map((f) => Chip(
            label: Text(f, style: const TextStyle(fontSize: 12)),
            backgroundColor: teal.withOpacity(0.05),
            side: BorderSide(color: teal.withOpacity(0.2)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickInfoSection(BuildContext context, BankInfo bank, Color gold) {
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: 16),
          _buildInfoRow(context, Icons.money, 'Min FD Amount', '₹1,000'),
          _buildInfoRow(context, Icons.calendar_today, 'Max Tenure', '10 Years'),
          _buildInfoRow(context, Icons.support_agent, 'Customer Care', '1800-XXX-XXXX', isLink: true, color: gold),
          _buildInfoRow(context, Icons.language, 'Website', 'www.${bank.name.replaceAll(' ', '').toLowerCase()}.com', isLink: true, color: gold),
          _buildInfoRow(context, Icons.location_city, 'Total Branches', '5,000+'),
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
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isLink ? (color ?? Theme.of(context).primaryColor) : Theme.of(context).textTheme.bodyMedium?.color,
              decoration: isLink ? TextDecoration.underline : null,
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
