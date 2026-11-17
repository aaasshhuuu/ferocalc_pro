import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/models/staged_candidate.dart';
import 'admin_status_badge.dart';

/// Card item representing a staged candidate in the Rate Review Queue.
class RateReviewQueueCard extends StatelessWidget {
  const RateReviewQueueCard({
    Key? key,
    required this.candidate,
    required this.onTap,
  }) : super(key: key);

  final StagedCandidate candidate;
  final VoidCallback onTap;

  String _formatCurrency(double? amount) {
    if (amount == null) return 'N/A';
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)} Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)} L';
    } else {
      return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyRange = '${_formatCurrency(candidate.minDeposit)} - ${_formatCurrency(candidate.maxDeposit)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: candidate.isInvalid
              ? FeroColors.error.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header: Bank code, Product, Staging Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: FeroColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        candidate.bankCode,
                        style: const TextStyle(
                          color: FeroColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.productType ?? 'Retail Domestic FD',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            candidate.displayTenure,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AdminStatusBadge.forStagingStatus(candidate.stagingStatus),
                  ],
                ),
                const SizedBox(height: 12),

                // Rates row: Proposed Rate, Diff, Senior Citizen Rate
                Row(
                  children: [
                    Text(
                      '${candidate.interestRate.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: FeroColors.gold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (candidate.diff != null) ...[
                      AdminStatusBadge.forDiffType(
                        candidate.diff!.diffType,
                        rateDelta: candidate.diff!.rateDelta,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (candidate.seniorCitizenRate != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Sr: ${candidate.seniorCitizenRate!.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Meta row: Deposit boundaries, Customer category, Effective date
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 13, color: Theme.of(context).textTheme.bodySmall?.color,),
                    const SizedBox(width: 4),
                    Text(
                      currencyRange,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.people_outline,
                        size: 13, color: Theme.of(context).textTheme.bodySmall?.color,),
                    const SizedBox(width: 4),
                    Text(
                      candidate.customerType,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    if (candidate.effectiveFrom != null) ...[
                      Icon(Icons.event_outlined,
                          size: 13, color: Theme.of(context).textTheme.bodySmall?.color,),
                      const SizedBox(width: 4),
                      Text(
                        candidate.effectiveFrom!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),

                // Warnings or Anomaly strip
                if (candidate.validationErrors.isNotEmpty || candidate.anomalyFlags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: candidate.isInvalid
                          ? FeroColors.error.withValues(alpha: 0.12)
                          : FeroColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          candidate.isInvalid ? Icons.error_outline : Icons.warning_amber_rounded,
                          size: 14,
                          color: candidate.isInvalid ? FeroColors.error : FeroColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            candidate.validationErrors.isNotEmpty
                                ? candidate.validationErrors.first
                                : 'Anomaly: ${candidate.anomalyFlags.first}',
                            style: TextStyle(
                              color: candidate.isInvalid ? FeroColors.error : FeroColors.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
