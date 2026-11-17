import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/verified_fd_rate.dart';
import '../../../../core/widgets/glassmorphic_card.dart';

/// Section G: Verified Fixed Deposit Rate Highlights & Data Trust Center Access
class VerifiedFdOpportunitiesSection extends StatelessWidget {
  const VerifiedFdOpportunitiesSection({
    Key? key,
    required this.verifiedRates,
    required this.favoriteBankIds,
    required this.isLoading,
    this.errorMessage,
    required this.onOpenBestForMeFd,
    required this.onOpenDataTrustCenter,
    required this.onOpenFavoriteBanks,
    required this.onOpenFdCalculator,
    required this.onRefresh,
  }) : super(key: key);

  final List<VerifiedFdRate> verifiedRates;
  final Set<String> favoriteBankIds;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onOpenBestForMeFd;
  final VoidCallback onOpenDataTrustCenter;
  final VoidCallback onOpenFavoriteBanks;
  final ValueChanged<VerifiedFdRate> onOpenFdCalculator;
  final VoidCallback onRefresh;

  static const Color gold = Color(0xFFC9A96E);
  static const Color emerald = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 20, color: emerald),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Verified FD Opportunities',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: gold),
              tooltip: 'Refresh Verified Rates',
              onPressed: onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 10),

        GlassmorphicCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Banner: Best for Me & Data Trust Center links
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onOpenBestForMeFd,
                        icon: const Icon(Icons.explore_outlined, size: 16),
                        label: const Text(
                          'Smart FD Discovery',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onOpenDataTrustCenter,
                        icon: const Icon(Icons.shield_outlined, size: 16, color: emerald),
                        label: const Text(
                          'Data Trust Center',
                          style: TextStyle(
                            fontSize: 12,
                            color: emerald,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: emerald),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Content: Loading, Error, Empty, or Populated List
                if (isLoading) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(gold),
                      ),
                    ),
                  ),
                ] else if (verifiedRates.isEmpty) ...[
                  _buildHonestEmptyState(context, isDark),
                ] else ...[
                  const Text(
                    'Active Verified Rate Highlights',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Official card rates verified from primary schedule bank notifications.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: verifiedRates.take(5).length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final rate = verifiedRates[idx];
                      final isFav = favoriteBankIds.contains(rate.bankId);
                      return _buildRateItem(context, rate, isFav, isDark);
                    },
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: onOpenFavoriteBanks,
                      icon: const Icon(Icons.star_outline, size: 16, color: gold),
                      label: const Text(
                        'Manage Favorite Banks',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: gold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHonestEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.signal_cellular_connected_no_internet_0_bar,
            size: 32,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
          const SizedBox(height: 10),
          const Text(
            'Verified Bank Rates Unavailable',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            errorMessage ??
                'No live verified bank rates are available right now. In compliance with FeroCalc data trust rules, unverified, draft, or stale rates are never displayed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onOpenDataTrustCenter,
            icon: const Icon(Icons.shield_outlined, size: 14, color: emerald),
            label: const Text(
              'Inspect Verification Pipeline',
              style: TextStyle(fontSize: 11, color: emerald),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateItem(
    BuildContext context,
    VerifiedFdRate rate,
    bool isFavorite,
    bool isDark,
  ) {
    final effectiveStr = DateFormat('dd MMM yyyy').format(rate.effectiveFrom);

    return InkWell(
      onTap: () => onOpenFdCalculator(rate),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFavorite
                ? gold.withOpacity(0.4)
                : (isDark ? Colors.white10 : Colors.black12),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: gold.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance, color: gold, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          rate.bankShortName.isNotEmpty
                              ? rate.bankShortName
                              : rate.bankName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFavorite) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FAVORITE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: gold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Effective: $effectiveStr',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${rate.interestRate.toStringAsFixed(2)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: emerald,
                  ),
                ),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 11, color: emerald),
                    SizedBox(width: 2),
                    Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: emerald,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
