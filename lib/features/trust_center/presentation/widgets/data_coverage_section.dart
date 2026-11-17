import 'package:flutter/material.dart';
import '../../../../core/models/bank.dart';
import '../../../../core/models/data_trust_models.dart';

class DataCoverageSection extends StatelessWidget {
  const DataCoverageSection({
    Key? key,
    required this.metrics,
    required this.isLoading,
    this.errorMessage,
    required this.onRetry,
    this.onSelectBankForHistory,
  }) : super(key: key);

  final DataCoverageMetrics? metrics;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<Bank>? onSelectBankForHistory;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC9A96E);
    const cyan = Color(0xFF38BDF8);

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5, color: gold),
              SizedBox(height: 16),
              Text(
                'Loading verified data coverage metrics...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16, color: gold),
              label: const Text('Retry', style: TextStyle(color: gold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: gold),
              ),
            ),
          ],
        ),
      );
    }

    final data = metrics;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final awaitingBanks = data.supportedSourcesAwaitingVerification;
    final otherCatalogBanks = data.catalogOnlyBanks.isNotEmpty
        ? data.catalogOnlyBanks
        : data.unsupportedBanks.where((b) => !awaitingBanks.any((a) => a.id == b.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Highlights
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                context,
                title: 'Verified Banks',
                value: '${data.activeVerifiedBanksCount}',
                subtitle: 'Active in pilot engine',
                icon: Icons.account_balance,
                accentColor: gold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                context,
                title: 'Verified Slabs',
                value: '${data.totalVerifiedRatesCount}',
                subtitle: 'Published rate records',
                icon: Icons.verified,
                accentColor: cyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Verified Banks List
        const Text(
          'BANKS WITH ACTIVE VERIFIED RATES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: gold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rates for these institutions are retrieved directly from official primary circulars and undergo multi-step consistency validation.',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        if (data.verifiedBanks.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.white54),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No bank has completed live verification yet. All calculations continue using unverified baseline data.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.verifiedBanks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final bank = data.verifiedBanks[idx];
              final slabCount = data.verifiedSlabsCountByBank[bank.id];
              final isUnavailable = data.temporarilyUnavailableBanks.any((b) => b.id == bank.id);
              return _buildBankCoverageTile(
                context,
                bank,
                isVerified: true,
                slabCount: slabCount,
                isTemporarilyUnavailable: isUnavailable,
              );
            },
          ),

        // Supported sources awaiting verification
        if (awaitingBanks.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'OFFICIAL SOURCES AWAITING VERIFICATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Official interest-rate sources for these institutions have been registered in the collection pipeline. Slabs are undergoing verification review and are strictly segregated from active published rates.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: awaitingBanks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final bank = awaitingBanks[idx];
              return _buildBankCoverageTile(
                context,
                bank,
                isVerified: false,
                isAwaitingVerification: true,
              );
            },
          ),
        ],

        // Unsupported / In-Queue Banks
        if (otherCatalogBanks.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'OTHER CATALOG BANKS (AWAITING VERIFIED PIPELINE)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These banks are registered in our institutional catalog but do not yet have published verified rate cards. They are strictly segregated from official verified results.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: otherCatalogBanks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, idx) {
              final bank = otherCatalogBanks[idx];
              return _buildBankCoverageTile(context, bank, isVerified: false);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Semantics(
      label: '$title: $value, $subtitle',
      readOnly: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF132235),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(icon, size: 18, color: accentColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCoverageTile(
    BuildContext context,
    Bank bank, {
    required bool isVerified,
    int? slabCount,
    bool isTemporarilyUnavailable = false,
    bool isAwaitingVerification = false,
  }) {
    const gold = Color(0xFFC9A96E);

    String subtitleText;
    Color subtitleColor;
    IconData leadingIcon;
    Color leadingColor;

    if (isVerified) {
      if (isTemporarilyUnavailable) {
        subtitleText = slabCount != null && slabCount > 0
            ? '$slabCount verified rate slabs • Source check retrying'
            : 'Verified rate slabs available • Source check retrying';
        subtitleColor = Colors.orangeAccent;
        leadingIcon = Icons.warning_amber_outlined;
        leadingColor = Colors.orangeAccent;
      } else {
        subtitleText = slabCount != null && slabCount > 0
            ? '$slabCount verified rate slabs available'
            : 'Verified rate slabs available';
        subtitleColor = const Color(0xFF10B981);
        leadingIcon = Icons.check_circle_outline;
        leadingColor = const Color(0xFF10B981);
      }
    } else if (isAwaitingVerification) {
      subtitleText = 'Official source configured — Awaiting verification review';
      subtitleColor = Colors.amber;
      leadingIcon = Icons.hourglass_top_outlined;
      leadingColor = Colors.amber;
    } else {
      subtitleText = 'Catalog registration only — Unverified';
      subtitleColor = Colors.white54;
      leadingIcon = Icons.pending_outlined;
      leadingColor = Colors.white38;
    }

    return Semantics(
      label: '${bank.name}, $subtitleText',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isVerified
                ? gold.withValues(alpha: 0.25)
                : (isAwaitingVerification
                    ? Colors.amber.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: leadingColor.withValues(alpha: 0.15),
              child: Icon(
                leadingIcon,
                size: 18,
                color: leadingColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isVerified && onSelectBankForHistory != null)
              Semantics(
                button: true,
                label: 'View verified rate history for ${bank.name}',
                child: TextButton(
                  onPressed: () => onSelectBankForHistory!(bank),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'History',
                        style: TextStyle(fontSize: 12, color: gold),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: gold),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
