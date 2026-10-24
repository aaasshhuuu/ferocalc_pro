import 'package:flutter/material.dart';

import '../../../../core/data/bank_rate_repository.dart';
import '../../../../core/models/bank.dart';
import '../../../../core/models/fd_rate.dart';
import '../../../../core/models/two_bank_comparison.dart';
import '../../../../core/services/rate_display_config.dart';
import '../../../../core/utils/financial_math.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/official_rates_notice_card.dart';
import '../../../../core/widgets/verification_badge.dart';

/// Screen allowing users to select two banks and compare their available
/// FD rates, customer types, deposit terms, and profile metadata side-by-side.
class TwoBankComparisonScreen extends StatefulWidget {
  const TwoBankComparisonScreen({
    Key? key,
    this.initialBankAId,
    this.initialBankBId,
  }) : super(key: key);

  final String? initialBankAId;
  final String? initialBankBId;

  @override
  State<TwoBankComparisonScreen> createState() => _TwoBankComparisonScreenState();
}

class _TwoBankComparisonScreenState extends State<TwoBankComparisonScreen> {
  late List<Bank> _allBanks;
  Bank? _bankA;
  Bank? _bankB;
  CustomerType _customerType = CustomerType.regular;

  static const Color gold = Color(0xFFC9A96E);

  @override
  void initState() {
    super.initState();
    _allBanks = BankRateRepository.getActiveBanks();
    if (_allBanks.isEmpty) {
      _allBanks = BankRateRepository.getAllBanks();
    }

    // Initialize Bank A
    if (widget.initialBankAId != null) {
      _bankA = BankRateRepository.getBankById(widget.initialBankAId!);
    }
    _bankA ??= _allBanks.isNotEmpty ? _allBanks[0] : null;

    // Initialize Bank B (ensure different from Bank A)
    if (widget.initialBankBId != null) {
      final potentialB = BankRateRepository.getBankById(widget.initialBankBId!);
      if (potentialB != null && potentialB.id != _bankA?.id) {
        _bankB = potentialB;
      }
    }
    if (_bankB == null && _allBanks.length > 1) {
      _bankB = _allBanks.firstWhere(
        (b) => b.id != _bankA?.id,
        orElse: () => _allBanks[1],
      );
    }
  }

  void _swapBanks() {
    if (_bankA == null || _bankB == null) return;
    setState(() {
      final temp = _bankA;
      _bankA = _bankB;
      _bankB = temp;
    });
  }

  void _selectBank({required bool isBankA}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BankPickerSheet(
        allBanks: _allBanks,
        currentlySelectedId: isBankA ? _bankA?.id : _bankB?.id,
        otherBankId: isBankA ? _bankB?.id : _bankA?.id,
        onSelected: (selectedBank) {
          Navigator.of(ctx).pop();
          // Same-bank prevention
          final oppositeBankId = isBankA ? _bankB?.id : _bankA?.id;
          if (selectedBank.id == oppositeBankId) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot select the same bank on both sides.'),
                backgroundColor: Colors.redAccent,
              ),
            );
            return;
          }

          setState(() {
            if (isBankA) {
              _bankA = selectedBank;
            } else {
              _bankB = selectedBank;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_bankA == null || _bankB == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Compare Two Banks'),
        body: const Center(child: Text('Insufficient bank data available for comparison.')),
      );
    }

    final comparison = TwoBankComparison.build(
      bankA: _bankA!,
      bankB: _bankB!,
      customerType: _customerType,
    );

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[50],
      appBar: const CustomAppBar(title: 'Compare Two Banks', showBackButton: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: Responsive.screenPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bank Selection Card with Swap Action
                  _buildSelectionCard(context, isDark),
                  const SizedBox(height: 16),

                  // Customer Type Toggle (Regular vs Senior)
                  _buildCustomerTypeToggle(context, isDark),
                  const SizedBox(height: 16),

                  // Side-by-side Overview Header
                  _buildComparisonHeader(context, comparison, isDark),
                  const SizedBox(height: 16),

                  // Section 1: Like-for-Like FD Interest Rates
                  _buildFdRatesSection(context, comparison, isDark),
                  const SizedBox(height: 16),

                  // Section 2: Other Rates & Deposit Terms
                  _buildDepositTermsSection(context, comparison, isDark),
                  const SizedBox(height: 16),

                  // Section 3: Bank Profile & Institutional Details
                  _buildBankProfileSection(context, comparison, isDark),
                  const SizedBox(height: 16),

                  // Section 4: Data Freshness & Disclaimer Notice
                  _buildTransparencyNotice(context, isDark),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard(BuildContext context, bool isDark) {
    return GlassmorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Banks to Compare',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Bank A Selector Box
              Expanded(
                child: _buildBankSelectorBox(
                  context: context,
                  isDark: isDark,
                  bank: _bankA!,
                  label: 'Bank A',
                  onTap: () => _selectBank(isBankA: true),
                  selectorKey: const ValueKey('select_bank_a_button'),
                ),
              ),
              const SizedBox(width: 8),

              // Swap Button
              InkWell(
                key: const ValueKey('swap_banks_button'),
                onTap: _swapBanks,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: gold.withAlpha(35),
                    shape: BoxShape.circle,
                    border: Border.all(color: gold.withAlpha(80)),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: gold, size: 22),
                ),
              ),
              const SizedBox(width: 8),

              // Bank B Selector Box
              Expanded(
                child: _buildBankSelectorBox(
                  context: context,
                  isDark: isDark,
                  bank: _bankB!,
                  label: 'Bank B',
                  onTap: () => _selectBank(isBankA: false),
                  selectorKey: const ValueKey('select_bank_b_button'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankSelectorBox({
    required BuildContext context,
    required bool isDark,
    required Bank bank,
    required String label,
    required VoidCallback onTap,
    required Key selectorKey,
  }) {
    return InkWell(
      key: selectorKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2634) : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: gold,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down, size: 16, color: gold),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              bank.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              bank.typeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTypeToggle(BuildContext context, bool isDark) {
    return GlassmorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Category',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Applies rates for both banks',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<CustomerType>(
            key: const ValueKey('two_bank_customer_segmented_button'),
            segments: const [
              ButtonSegment(
                value: CustomerType.regular,
                label: Text('Regular', style: TextStyle(fontSize: 11.5)),
              ),
              ButtonSegment(
                value: CustomerType.seniorCitizen,
                label: Text('Senior', style: TextStyle(fontSize: 11.5)),
              ),
            ],
            selected: {_customerType},
            onSelectionChanged: (val) {
              setState(() => _customerType = val.first);
            },
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              side: WidgetStateProperty.all(
                BorderSide(color: isDark ? Colors.white24 : Colors.black12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonHeader(BuildContext context, TwoBankComparison comp, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildBankHeaderPill(
            context: context,
            bank: comp.bankA,
            side: 'A',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'VS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBankHeaderPill(
            context: context,
            bank: comp.bankB,
            side: 'B',
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildBankHeaderPill({
    required BuildContext context,
    required Bank bank,
    required String side,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16212E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: gold.withAlpha(side == 'A' ? 100 : 70),
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: gold.withAlpha(35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Bank $side',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: gold,
                  ),
                ),
              ),
              const Spacer(),
              const VerificationBadge(
                status: VerificationStatus.pendingReview,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            bank.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            bank.typeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFdRatesSection(BuildContext context, TwoBankComparison comp, bool isDark) {
    if (!RateDisplayConfig.isLiveRateDisplayEnabled) {
      return const OfficialRatesNoticeCard(
        title: 'FD Interest Rates Comparison',
        message: 'Official bank rates are being verified and will be available in a future update.',
        subtext: 'Side-by-side interest rate comparisons will be activated once official rate attestations are completed directly from primary bank sources.',
      );
    }

    final categoryLabel = _customerType == CustomerType.seniorCitizen ? 'Senior Citizen' : 'Regular Customer';

    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.percent_rounded, size: 18, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'FD Interest Rates ($categoryLabel)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Like-for-like callable term deposit rates per annum',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),

          // Tenure Rows
          ...comp.tenureComparisons.map((item) => _buildTenureComparisonRow(
                context: context,
                item: item,
                bankA: comp.bankA,
                bankB: comp.bankB,
                isDark: isDark,
              )),
        ],
      ),
    );
  }

  Widget _buildTenureComparisonRow({
    required BuildContext context,
    required TenureComparisonItem item,
    required Bank bankA,
    required Bank bankB,
    required bool isDark,
  }) {
    final hasA = item.rateA != null;
    final hasB = item.rateB != null;

    final isAWinner = item.winner == ComparisonWinner.bankA;
    final isBWinner = item.winner == ComparisonWinner.bankB;
    final isTie = item.winner == ComparisonWinner.tie;

    String diffText = '';
    if (isTie) {
      diffText = 'Rates are equal';
    } else if (isAWinner && item.difference != null) {
      diffText = '${bankA.shortName.isNotEmpty ? bankA.shortName : bankA.name} is +${item.difference!.toStringAsFixed(2)}% higher';
    } else if (isBWinner && item.difference != null) {
      diffText = '${bankB.shortName.isNotEmpty ? bankB.shortName : bankB.name} is +${item.difference!.toStringAsFixed(2)}% higher';
    } else {
      diffText = 'Comparison incomplete (missing data)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141D27) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.tenureLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.difference != null && !isTie)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Diff: ${item.difference!.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E676),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Bank A Rate
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isAWinner ? gold.withAlpha(25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isAWinner ? Border.all(color: gold, width: 1) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bankA.shortName.isNotEmpty ? bankA.shortName : 'Bank A',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasA ? '${item.rateA!.toStringAsFixed(2)}% p.a.' : 'Not available',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: hasA
                              ? (isAWinner ? gold : (isDark ? Colors.white : Colors.black87))
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Bank B Rate
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isBWinner ? gold.withAlpha(25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isBWinner ? Border.all(color: gold, width: 1) : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bankB.shortName.isNotEmpty ? bankB.shortName : 'Bank B',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasB ? '${item.rateB!.toStringAsFixed(2)}% p.a.' : 'Not available',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: hasB
                              ? (isBWinner ? gold : (isDark ? Colors.white : Colors.black87))
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            diffText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: isTie
                  ? Colors.grey
                  : (isAWinner || isBWinner ? (isDark ? Colors.white60 : Colors.black54) : Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositTermsSection(BuildContext context, TwoBankComparison comp, bool isDark) {
    final infoA = comp.bankInfoA;
    final infoB = comp.bankInfoB;

    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 18, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Other Rates & Deposit Terms',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildSideBySideMetricRow(
            label: 'Senior Citizen Premium',
            valA: infoA != null && infoA.seniorCitizenExtra > 0
                ? '+${infoA.seniorCitizenExtra.toStringAsFixed(2)}% p.a.'
                : 'Not available',
            valB: infoB != null && infoB.seniorCitizenExtra > 0
                ? '+${infoB.seniorCitizenExtra.toStringAsFixed(2)}% p.a.'
                : 'Not available',
            isDark: isDark,
          ),
          const Divider(height: 16),

          _buildSideBySideMetricRow(
            label: 'Savings Account Rate',
            valA: infoA?.savingsRate != null ? '${infoA!.savingsRate!.toStringAsFixed(2)}% p.a.' : 'Not available',
            valB: infoB?.savingsRate != null ? '${infoB!.savingsRate!.toStringAsFixed(2)}% p.a.' : 'Not available',
            isDark: isDark,
          ),
          const Divider(height: 16),

          _buildSideBySideMetricRow(
            label: 'Minimum FD Deposit',
            valA: infoA != null ? FinancialMath.formatCurrencyRounded(infoA.minFdAmount.toDouble()) : 'Not available',
            valB: infoB != null ? FinancialMath.formatCurrencyRounded(infoB.minFdAmount.toDouble()) : 'Not available',
            isDark: isDark,
          ),
          const Divider(height: 16),

          _buildSideBySideMetricRow(
            label: 'Maximum FD Tenure',
            valA: infoA?.maxFdTenure.isNotEmpty == true ? infoA!.maxFdTenure : 'Not available',
            valB: infoB?.maxFdTenure.isNotEmpty == true ? infoB!.maxFdTenure : 'Not available',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildBankProfileSection(BuildContext context, TwoBankComparison comp, bool isDark) {
    final bA = comp.bankA;
    final bB = comp.bankB;

    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.corporate_fare_rounded, size: 18, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bank Profile & Overview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildSideBySideMetricRow(
            label: 'Institution Category',
            valA: bA.typeLabel,
            valB: bB.typeLabel,
            isDark: isDark,
          ),
          const Divider(height: 16),

          _buildSideBySideMetricRow(
            label: 'Established Year',
            valA: bA.established?.isNotEmpty == true ? bA.established! : 'Not available',
            valB: bB.established?.isNotEmpty == true ? bB.established! : 'Not available',
            isDark: isDark,
          ),
          const Divider(height: 16),

          _buildSideBySideMetricRow(
            label: 'Headquarters',
            valA: bA.headquarters?.isNotEmpty == true ? bA.headquarters! : 'Not available',
            valB: bB.headquarters?.isNotEmpty == true ? bB.headquarters! : 'Not available',
            isDark: isDark,
          ),
          const Divider(height: 16),

          _buildSideBySideMetricRow(
            label: 'Branch Network',
            valA: bA.totalBranches?.isNotEmpty == true ? bA.totalBranches! : 'Not available',
            valB: bB.totalBranches?.isNotEmpty == true ? bB.totalBranches! : 'Not available',
            isDark: isDark,
          ),
          const Divider(height: 16),

          _buildSideBySideMetricRow(
            label: 'Customer Care',
            valA: bA.customerCareNumber?.isNotEmpty == true ? bA.customerCareNumber! : 'Not available',
            valB: bB.customerCareNumber?.isNotEmpty == true ? bB.customerCareNumber! : 'Not available',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSideBySideMetricRow({
    required String label,
    required String valA,
    required String valB,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                valA,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: valA == 'Not available'
                      ? Colors.grey
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                valB,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: valB == 'Not available'
                      ? Colors.grey
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransparencyNotice(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(6) : Colors.black.withAlpha(4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, size: 15, color: gold),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Rate Verification & Data Notice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• FD and bank interest rates shown above reflect standard callable deposit slabs from available bank datasets.\n'
            '• All current rates are pending official bank verification. Banks frequently update interest rates without prior notice.\n'
            '• Always verify prevailing rates with the respective official bank branches or websites before opening an account.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.4,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet modal to search and pick a bank.
class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({
    required this.allBanks,
    this.currentlySelectedId,
    this.otherBankId,
    required this.onSelected,
  });

  final List<Bank> allBanks;
  final String? currentlySelectedId;
  final String? otherBankId;
  final ValueChanged<Bank> onSelected;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFC9A96E);

    final filtered = widget.allBanks.where((b) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      return b.name.toLowerCase().contains(q) ||
          b.shortName.toLowerCase().contains(q) ||
          b.typeLabel.toLowerCase().contains(q);
    }).toList();

    return Material(
      color: isDark ? const Color(0xFF16212E) : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Select Bank',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                key: const ValueKey('bank_picker_search_field'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search bank name...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E2D3D) : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final bank = filtered[index];
                  final isCurrent = bank.id == widget.currentlySelectedId;
                  final isOther = bank.id == widget.otherBankId;

                  return ListTile(
                    key: ValueKey('bank_item_${bank.id}'),
                    enabled: !isOther,
                    leading: CircleAvatar(
                      backgroundColor: gold.withAlpha(isOther ? 15 : 30),
                      child: Text(
                        bank.shortName.isNotEmpty
                            ? bank.shortName.substring(0, bank.shortName.length.clamp(1, 3))
                            : bank.name.substring(0, 1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOther ? Colors.grey : gold,
                        ),
                      ),
                    ),
                    title: Text(
                      bank.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isOther
                            ? Colors.grey
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    subtitle: Text(
                      isOther ? 'Already selected on other side' : bank.typeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isOther ? Colors.redAccent.withAlpha(200) : (isDark ? Colors.white54 : Colors.black54),
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check_circle, color: gold, size: 20)
                        : (isOther ? const Icon(Icons.block, color: Colors.grey, size: 18) : null),
                    onTap: isOther ? null : () => widget.onSelected(bank),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
