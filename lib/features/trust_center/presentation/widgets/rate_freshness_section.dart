import 'package:flutter/material.dart';
import '../../../../core/models/data_trust_models.dart';
import '../../../../core/utils/date_formatter.dart';

class RateFreshnessSection extends StatelessWidget {
  const RateFreshnessSection({
    Key? key,
    required this.freshnessResponse,
    required this.isLoading,
    this.errorMessage,
    required this.onRefresh,
  }) : super(key: key);

  final RateFreshnessResponse? freshnessResponse;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC9A96E);
    const cyan = Color(0xFF38BDF8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with manual refresh button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'OFFICIAL RATE FRESHNESS TELEMETRY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: gold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: gold),
                    )
                  : const Icon(Icons.refresh, color: gold, size: 20),
              tooltip: 'Check source freshness',
              onPressed: isLoading ? null : onRefresh,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Automated health telemetry from our scheduled bank collection jobs. Freshness telemetry tracks ingestion checks independently of rate verification updates.',
          style: TextStyle(
            fontSize: 12.5,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Crucial Architectural Principles Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF132235),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cyan.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: cyan),
                  SizedBox(width: 8),
                  Text(
                    'Consumer Integrity Guarantees',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: cyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPrincipleRow(
                'Collection Check ≠ Verification',
                'last_checked_at indicates when our bot verified the bank website was reachable. verified_at records when the rate card was promoted.',
              ),
              const SizedBox(height: 6),
              _buildPrincipleRow(
                'No Automatic Invalidation',
                'A temporary bank server error or network failure does not delete or invalidate existing verified rates.',
              ),
              const SizedBox(height: 6),
              _buildPrincipleRow(
                'Segregated Candidate Promotion',
                'A newly detected rate change awaiting review never replaces the active verified rate until formally approved.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (isLoading && freshnessResponse == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: CircularProgressIndicator(color: gold, strokeWidth: 2.5),
            ),
          )
        else if (errorMessage != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
                TextButton(
                  onPressed: onRefresh,
                  child: const Text('Retry', style: TextStyle(color: gold)),
                ),
              ],
            ),
          )
        else if (freshnessResponse != null) ...[
          // Telemetry overview summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sources Monitored: ${freshnessResponse!.count}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: freshnessResponse!.allFresh
                            ? const Color(0xFF10B981)
                            : (freshnessResponse!.anyUpdatePending
                                ? const Color(0xFFF59E0B)
                                : Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      freshnessResponse!.anyUpdatePending
                          ? 'Updates In Review'
                          : (freshnessResponse!.allFresh ? 'All Healthy' : 'Checks Pending'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: freshnessResponse!.allFresh
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Source Telemetry Cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: freshnessResponse!.sources.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final src = freshnessResponse!.sources[idx];
              return _buildSourceCard(context, src);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPrincipleRow(String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: Colors.white54, fontSize: 13)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.35),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceCard(BuildContext context, RateFreshnessInfo src) {
    final state = src.consumerState;
    final stateColor = _colorForState(state);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stateColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  src.bankName.isNotEmpty ? src.bankName : src.bankCode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: stateColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconForState(state), size: 12, color: stateColor),
                    const SizedBox(width: 4),
                    Text(
                      state.shortLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: stateColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Safe Public Messaging
          Text(
            src.publicStatusDescription,
            style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 10),

          // Timestamps breakdown
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildTimestampRow(
                  'Last Source Ingestion Check',
                  src.lastCheckedAt != null
                      ? DateFormatter.formatFullDateTime(src.lastCheckedAt!)
                      : 'Never checked',
                ),
                const SizedBox(height: 4),
                _buildTimestampRow(
                  'Last Successful Fetch',
                  src.lastSuccessAt != null
                      ? DateFormatter.formatFullDateTime(src.lastSuccessAt!)
                      : 'Pending first baseline run',
                ),
                if (src.pendingReviewCount > 0) ...[
                  const SizedBox(height: 4),
                  _buildTimestampRow(
                    'Candidates Under Review',
                    '${src.pendingReviewCount} slab${src.pendingReviewCount > 1 ? 's' : ''} awaiting approval',
                    highlightColor: const Color(0xFFF59E0B),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampRow(String label, String value, {Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: highlightColor ?? Colors.white70,
          ),
        ),
      ],
    );
  }

  Color _colorForState(ConsumerFreshnessState state) {
    switch (state) {
      case ConsumerFreshnessState.recentlyChecked:
        return const Color(0xFF10B981);
      case ConsumerFreshnessState.verificationUpdatePending:
        return const Color(0xFFF59E0B);
      case ConsumerFreshnessState.olderData:
        return const Color(0xFFEAB308);
      case ConsumerFreshnessState.sourceUnavailable:
        return const Color(0xFFEF4444);
      case ConsumerFreshnessState.freshnessInfoUnavailable:
        return Colors.grey;
    }
  }

  IconData _iconForState(ConsumerFreshnessState state) {
    switch (state) {
      case ConsumerFreshnessState.recentlyChecked:
        return Icons.check_circle;
      case ConsumerFreshnessState.verificationUpdatePending:
        return Icons.hourglass_top;
      case ConsumerFreshnessState.olderData:
        return Icons.history;
      case ConsumerFreshnessState.sourceUnavailable:
        return Icons.cloud_off;
      case ConsumerFreshnessState.freshnessInfoUnavailable:
        return Icons.help_outline;
    }
  }
}
