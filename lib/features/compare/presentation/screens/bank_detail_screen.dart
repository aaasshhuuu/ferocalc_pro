import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/bank_data.dart';
import '../../../../core/data/bank_rate_repository.dart';
import '../../../../core/models/bank.dart';
import '../../../../core/models/fd_rate.dart';
import '../../../../core/models/verified_fd_rate.dart';
import '../../../../core/services/rate_display_config.dart';
import '../../../../core/services/verified_rate_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/official_rates_notice_card.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../core/widgets/verified_rate_badge.dart';

class BankDetailScreen extends StatefulWidget {
  final String bankName;

  const BankDetailScreen({Key? key, required this.bankName}) : super(key: key);

  /// Safely normalizes a bank website URL into a valid Uri.
  static Uri? normalizeWebsiteUri(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final String trimmed = rawUrl.trim();
    final String withScheme = (!trimmed.startsWith('http://') && !trimmed.startsWith('https://'))
        ? 'https://$trimmed'
        : trimmed;
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri;
  }

  /// Opens the bank's official website in the external browser.
  static Future<bool> launchBankWebsite(BuildContext context, String? rawUrl) async {
    final uri = normalizeWebsiteUri(rawUrl);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid or unavailable bank website URL'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }

    try {
      bool launched = false;
      try {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open bank website'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return launched;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening website: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }
  }

  @override
  State<BankDetailScreen> createState() => _BankDetailScreenState();
}

class _BankDetailScreenState extends State<BankDetailScreen> {
  List<VerifiedFdRate> _verifiedRates = [];
  bool _isLoadingVerified = false;

  @override
  void initState() {
    super.initState();
    _loadVerifiedRates();
  }

  Future<void> _loadVerifiedRates() async {
    setState(() => _isLoadingVerified = true);
    try {
      final res = await VerifiedRateService.fetchAll(isCallable: null);
      if (mounted) {
        final query = widget.bankName.toLowerCase().trim();
        final matched = res.rates.where((r) {
          final rName = r.bankName.toLowerCase();
          final rShort = r.bankShortName.toLowerCase();
          return rName == query ||
              rShort == query ||
              query.contains(rShort) ||
              query.contains(rName) ||
              rName.contains(query);
        }).toList();

        setState(() {
          _verifiedRates = matched;
          _isLoadingVerified = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVerified = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Try new model first, fall back to legacy
    final legacyBank = BankDataService.getBankByName(widget.bankName);
    final gold = const Color(0xFFC9A96E);

    if (legacyBank == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Bank Not Found'),
        body: const Center(child: Text('Bank details could not be found.')),
      );
    }

    // Find the new Bank model
    final bankId = widget.bankName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final bank = BankRateRepository.getBankById(bankId);
    final allRates = bank != null ? BankRateRepository.getRatesForBank(bankId) : <FdRate>[];
    // Default display shows callable rates only (preserving product clarity and preventing mixed slabs)
    final callableRates = allRates.where((r) => r.prematureWithdrawalAllowed).toList();
    final regularRates = callableRates.where((r) => r.customerType == CustomerType.regular).toList();
    final seniorRates = callableRates.where((r) => r.customerType == CustomerType.seniorCitizen).toList();

    // Preserve non-callable support in dedicated distinct section
    final nonCallableRates = allRates.where((r) => !r.prematureWithdrawalAllowed).toList();
    final nonCallableRegularRates = nonCallableRates.where((r) => r.customerType == CustomerType.regular).toList();
    final nonCallableSeniorRates = nonCallableRates.where((r) => r.customerType == CustomerType.seniorCitizen).toList();

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
              if (!RateDisplayConfig.isLiveRateDisplayEnabled) ...[
                OfficialRatesNoticeCard(
                  bankName: legacyBank.name,
                  officialWebsiteUrl: legacyBank.website,
                  onOpenCalculator: () => context.push('/calculator/fd'),
                ).animate().fade(delay: 100.ms),
              ] else ...[
                if (_verifiedRates.isNotEmpty) ...[
                  _buildVerifiedRatesCard(context, _verifiedRates, gold).animate().fade(delay: 50.ms),
                  const SizedBox(height: 24),
                  Text(
                    'Reference Historical Rates (Unverified)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildRateTable(context, 'FD Rates — Regular', regularRates, gold).animate().fade(delay: 100.ms),
                const SizedBox(height: 16),
                _buildRateTable(context, 'FD Rates — Senior Citizen', seniorRates, gold).animate().fade(delay: 200.ms),
                if (nonCallableRegularRates.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildRateTable(context, 'FD Rates — Non-Callable (No Premature Withdrawal)', nonCallableRegularRates, gold).animate().fade(delay: 220.ms),
                ],
                if (nonCallableSeniorRates.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildRateTable(context, 'FD Rates — Non-Callable Senior Citizen', nonCallableSeniorRates, gold).animate().fade(delay: 240.ms),
                ],
                const SizedBox(height: 24),
                _buildDataDisclaimer(context).animate().fade(delay: 250.ms),
              ],
              const SizedBox(height: 24),
              _buildBankInfo(context, legacyBank, bank, gold).animate().fade(delay: 300.ms),
              const SizedBox(height: 24),
              _buildQuickActions(context, gold, bank).animate().fade(delay: 400.ms),
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
                VerificationBadge(status: rates.first.verificationStatus, rate: rates.first, bankName: widget.bankName),
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

  Widget _buildVerifiedRatesCard(BuildContext context, List<VerifiedFdRate> rates, Color gold) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstRate = rates.first;
    final officialDomain = firstRate.bankSourceDomain ?? 'official bank website';
    final verifiedDateStr = firstRate.verifiedAt != null
        ? '${firstRate.verifiedAt!.day}/${firstRate.verifiedAt!.month}/${firstRate.verifiedAt!.year}'
        : 'Recent';

    final regularRates = rates.where((r) => r.customerType == VerifiedCustomerType.regular).toList();
    final seniorRates = rates.where((r) => r.customerType == VerifiedCustomerType.seniorCitizen).toList();

    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'Verified FD Rates',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8),
                        VerifiedRateBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Directly sourced from $officialDomain \u2022 Verified on $verifiedDateStr',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (firstRate.sourceUrl != null && firstRate.sourceUrl!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18, color: Color(0xFF10B981)),
                  tooltip: 'Open Official Source',
                  onPressed: () => BankDetailScreen.launchBankWebsite(context, firstRate.sourceUrl),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (regularRates.isNotEmpty) ...[
            Text(
              'Regular Depositors',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildVerifiedTable(context, regularRates, gold),
            const SizedBox(height: 16),
          ],
          if (seniorRates.isNotEmpty) ...[
            Text(
              'Senior Citizens',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _buildVerifiedTable(context, seniorRates, gold),
          ],
        ],
      ),
    );
  }

  Widget _buildVerifiedTable(BuildContext context, List<VerifiedFdRate> rates, Color gold) {
    final maxRate = rates.map((r) => r.interestRate).reduce(max);
    final hasSpecialScheme = rates.any((r) =>
        r.rateCategory == RateCategory.specialScheme ||
        (r.schemeName != null && r.schemeName!.trim().isNotEmpty));

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
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
                  decoration: const BoxDecoration(color: Color(0xFF052E16)),
                  children: [
                    _buildTableCell(context, 'Tenure', isHeader: true),
                    _buildTableCell(context, 'Rate', isHeader: true),
                    _buildTableCell(context, 'Status', isHeader: true),
                  ],
                ),
                ...rates.map((rate) {
                  final isHighest = rate.interestRate == maxRate;
                  final isSpecial = rate.rateCategory == RateCategory.specialScheme ||
                      (rate.schemeName != null && rate.schemeName!.trim().isNotEmpty);

                  return TableRow(
                    decoration: isHighest ? BoxDecoration(color: gold.withOpacity(0.08)) : null,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rate.tenureDescription,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isHighest ? FontWeight.bold : FontWeight.w500,
                                color: isHighest ? gold : null,
                              ),
                            ),
                            if (isSpecial) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                                ),
                                child: Text(
                                  'Special: ${rate.schemeName ?? 'Promotional'}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildTableCell(context, '${rate.interestRate.toStringAsFixed(2)}% p.a.', isHighlight: isHighest, gold: gold),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: isSpecial
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const VerifiedRateBadge(showLabel: true),
                                    if (rate.reviewNotes != null && rate.reviewNotes!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        rate.reviewNotes!,
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontStyle: FontStyle.italic,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                )
                              : const VerifiedRateBadge(showLabel: true),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          if (hasSpecialScheme) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 12, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Special scheme rates are subject to specific bank eligibility criteria and terms.',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
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

  Widget _buildBankInfo(BuildContext context, BankInfo legacyBank, Bank? bank, Color gold) {
    final websiteUrl = (bank?.officialWebsite != null && bank!.officialWebsite!.isNotEmpty)
        ? bank.officialWebsite!
        : legacyBank.website;

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
          if (websiteUrl.isNotEmpty)
            _buildInfoRow(
              context,
              Icons.language,
              'Official Website',
              websiteUrl,
              isLink: true,
              color: gold,
              onTap: () => BankDetailScreen.launchBankWebsite(context, websiteUrl),
            ),
          if (legacyBank.totalBranches.isNotEmpty)
            _buildInfoRow(context, Icons.location_city, 'Branches', legacyBank.totalBranches),
          if (legacyBank.established.isNotEmpty)
            _buildInfoRow(context, Icons.history, 'Established', legacyBank.established),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
    Color? color,
    VoidCallback? onTap,
  }) {
    final linkColor = color ?? Theme.of(context).primaryColor;
    final valueWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isLink ? linkColor : Theme.of(context).textTheme.bodyMedium?.color,
              decoration: isLink ? TextDecoration.underline : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isLink && onTap != null) ...[
          const SizedBox(width: 4),
          Icon(Icons.open_in_new, size: 14, color: linkColor),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
          const Spacer(),
          Flexible(
            child: onTap != null
                ? InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: valueWidget,
                    ),
                  )
                : valueWidget,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, Color gold, Bank? bank) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () => context.push('/calculator/fd'),
          icon: const Icon(Icons.calculate),
          label: const Text('Calculate FD Returns'),
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => context.push('/calculator/rd'),
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
          icon: const Icon(Icons.list_alt),
          label: const Text('Compare with Others'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('bank_detail_compare_two_banks_button'),
          onPressed: () => context.push('/compare/two-banks?bankA=${Uri.encodeComponent(bank?.id ?? '')}'),
          icon: const Icon(Icons.compare_arrows),
          label: const Text('Compare Side-by-Side'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
