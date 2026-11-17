import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/models/data_trust_models.dart';
import '../../../../core/models/verified_fd_rate.dart';
import '../../../../core/utils/date_formatter.dart';

class SourceTransparencySection extends StatelessWidget {
  const SourceTransparencySection({
    Key? key,
    required this.verifiedRates,
    required this.freshnessList,
    required this.isLoading,
  }) : super(key: key);

  final List<VerifiedFdRate> verifiedRates;
  final List<RateFreshnessInfo> freshnessList;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC9A96E);

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: CircularProgressIndicator(color: gold, strokeWidth: 2.5),
        ),
      );
    }

    // Group rates by bank to present unique bank sources
    final bankSources = <String, Map<String, dynamic>>{};

    for (final rate in verifiedRates) {
      final bankId = rate.bankId;
      if (!bankSources.containsKey(bankId)) {
        bankSources[bankId] = {
          'bankName': rate.bankName,
          'sourceUrl': rate.sourceUrl,
          'effectiveFrom': rate.effectiveFrom,
          'verifiedAt': rate.verifiedAt,
          'status': 'VERIFIED',
          'slabsCount': 1,
        };
      } else {
        final existing = bankSources[bankId]!;
        existing['slabsCount'] = (existing['slabsCount'] as int) + 1;
        // Keep the latest verifiedAt and effectiveFrom
        if (rate.verifiedAt != null) {
          final curr = existing['verifiedAt'] as DateTime?;
          if (curr == null || rate.verifiedAt!.isAfter(curr)) {
            existing['verifiedAt'] = rate.verifiedAt;
          }
        }
        final currEff = existing['effectiveFrom'] as DateTime?;
        if (currEff == null || rate.effectiveFrom.isAfter(currEff)) {
          existing['effectiveFrom'] = rate.effectiveFrom;
        }
        if (existing['sourceUrl'] == null && rate.sourceUrl != null) {
          existing['sourceUrl'] = rate.sourceUrl;
        }
      }
    }

    // Supplement with freshness registry sources if present
    for (final fresh in freshnessList) {
      final matchingEntry = bankSources.values.firstWhere(
        (b) => (b['bankName'] as String?)?.toLowerCase().contains(fresh.bankName.toLowerCase()) == true ||
               fresh.bankName.toLowerCase().contains((b['bankName'] as String? ?? '').toLowerCase()),
        orElse: () => {},
      );

      if (matchingEntry.isNotEmpty) {
        if (matchingEntry['sourceUrl'] == null || (matchingEntry['sourceUrl'] as String).isEmpty) {
          matchingEntry['sourceUrl'] = fresh.sourceUrl;
        }
      }
    }

    // Collect sources from freshness telemetry that do not yet have published verified rates
    final awaitingSources = <Map<String, dynamic>>[];
    for (final fresh in freshnessList) {
      final hasVerified = bankSources.values.any(
        (b) =>
            (b['bankName'] as String?)?.toLowerCase().contains(
                  fresh.bankName.toLowerCase(),
                ) ==
                true ||
            fresh.bankName.toLowerCase().contains(
                  (b['bankName'] as String? ?? '').toLowerCase(),
                ),
      );
      if (!hasVerified) {
        awaitingSources.add({
          'bankName': fresh.bankName,
          'sourceUrl': fresh.sourceUrl,
          'effectiveFrom': null,
          'verifiedAt': null,
          'status': 'AWAITING_VERIFICATION',
          'slabsCount': 0,
          'lastStatus': fresh.lastStatus,
          'isStale': fresh.isStale,
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OFFICIAL SOURCE TRANSPARENCY & PROVENANCE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: gold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Direct links to primary official circulars and rate pages. Every verified slab is auditable to its institutional source.',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        if (bankSources.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'No verified source records currently loaded.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bankSources.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final bankId = bankSources.keys.elementAt(idx);
              final info = bankSources[bankId]!;
              return _buildSourceCard(context, info);
            },
          ),

        // Sources Awaiting Verification Section
        if (awaitingSources.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'OFFICIAL SOURCES AWAITING VERIFICATION REVIEW',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Official primary bank sources configured and monitored in our ingestion pipeline, pending formal audit and promotion to public verified rates.',
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
            itemCount: awaitingSources.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final info = awaitingSources[idx];
              return _buildSourceCard(context, info);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSourceCard(BuildContext context, Map<String, dynamic> info) {
    const gold = Color(0xFFC9A96E);
    final bankName = info['bankName'] as String? ?? 'Official Bank';
    final sourceUrl = info['sourceUrl'] as String?;
    final effectiveFrom = info['effectiveFrom'] as DateTime?;
    final verifiedAt = info['verifiedAt'] as DateTime?;
    final slabsCount = info['slabsCount'] as int? ?? 0;
    final isAwaitingVerification = info['status'] == 'AWAITING_VERIFICATION';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAwaitingVerification
              ? Colors.amber.withValues(alpha: 0.25)
              : gold.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  bankName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isAwaitingVerification
                      ? Colors.amber.withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAwaitingVerification ? Icons.hourglass_top : Icons.verified,
                      size: 12,
                      color: isAwaitingVerification ? Colors.amber : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAwaitingVerification ? 'AWAITING REVIEW' : 'VERIFIED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isAwaitingVerification ? Colors.amber : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isAwaitingVerification
                ? 'Candidate rates pending verification review • No published slabs'
                : '$slabsCount verified rate slab${slabsCount > 1 ? 's' : ''} active',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 10),

          // Metadata table
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildRow(
                  'Effective Date:',
                  effectiveFrom != null
                      ? DateFormatter.formatStandardDate(effectiveFrom)
                      : (isAwaitingVerification ? 'Pending review' : 'Refer to circular'),
                ),
                const SizedBox(height: 4),
                _buildRow(
                  'Last Verified:',
                  verifiedAt != null
                      ? DateFormatter.formatStandardDate(verifiedAt)
                      : (isAwaitingVerification ? 'In review pipeline' : 'Verified baseline active'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Official URL Link
          if (sourceUrl != null && sourceUrl.isNotEmpty)
            InkWell(
              onTap: () async {
                final uri = Uri.tryParse(sourceUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: gold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 14, color: gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sourceUrl,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: gold,
                          decoration: TextDecoration.underline,
                          decorationColor: gold,
                        ),
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 12, color: gold),
                  ],
                ),
              ),
            )
          else
            const Text(
              'Source URL registered in internal verification registry.',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        Text(value, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}
