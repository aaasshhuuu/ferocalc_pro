import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/themes/app_colors.dart';
import 'glassmorphic_card.dart';

/// Launch-safe user-facing notice displayed in place of unverified or stale
/// bank FD rate tables, cards, and comparison lists.
///
/// Ensures compliance with launch safety requirements:
/// - Stale or unverified rates are never presented as official rates.
/// - Clearly states that rates are undergoing official verification.
/// - Provides direct actions to use independent calculators with custom rates
///   or visit official bank websites.
class OfficialRatesNoticeCard extends StatelessWidget {
  final String? bankName;
  final String? title;
  final String message;
  final String? subtext;
  final bool compact;
  final String? officialWebsiteUrl;
  final VoidCallback? onOpenCalculator;

  const OfficialRatesNoticeCard({
    Key? key,
    this.bankName,
    this.title,
    this.message = 'Official bank rates are being verified and will be available in a future update.',
    this.subtext,
    this.compact = false,
    this.officialWebsiteUrl,
    this.onOpenCalculator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFC9A96E);
    final displayTitle = title ?? (bankName != null ? 'Official $bankName Rates' : 'Official Bank Rates');
    final displaySubtext = subtext ??
        'Our automated rate ingestion and attestation pipeline is currently verifying interest rate slabs directly from official primary bank sources. You can use our independent calculators to compute returns with any custom rate.';

    if (compact) {
      return Container(
        key: const ValueKey('official_rates_pending_notice_compact'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF132235) : Colors.amber.shade50.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: gold.withOpacity(0.4),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: gold.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: gold, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: onOpenCalculator ?? () => context.push('/calculator/fd'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.calculate_outlined, size: 15, color: gold),
                    SizedBox(width: 6),
                    Text(
                      'Use FD Calculator with Custom Rate \u2192',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GlassmorphicCard(
      child: Container(
        key: const ValueKey('official_rates_pending_notice_card'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gold.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.verified_outlined, color: gold, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                        ),
                        child: const Text(
                          'Verification in Progress',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF60A5FA),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.25) : Colors.amber.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: gold.withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              displaySubtext,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: onOpenCalculator ?? () => context.push('/calculator/fd'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.calculate, size: 16),
                  label: const Text('Open FD Calculator', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/calculators'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: gold,
                    side: const BorderSide(color: gold),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.apps, size: 16),
                  label: const Text('Browse All Calculators', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
