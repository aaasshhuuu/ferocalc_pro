import 'package:flutter/material.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/models/admin_operational_metrics.dart';

/// Compact operational summary metrics grid for the Admin Dashboard.
class OperationalMetricsGrid extends StatelessWidget {
  const OperationalMetricsGrid({
    Key? key,
    required this.metrics,
    this.isLoading = false,
    this.onSelectStatus,
    this.selectedStatus,
  }) : super(key: key);

  final AdminOperationalMetrics? metrics;
  final bool isLoading;
  final ValueChanged<String>? onSelectStatus;
  final String? selectedStatus;

  @override
  Widget build(BuildContext context) {
    if (metrics != null && metrics!.isUnavailable) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: FeroColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: FeroColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 20, color: FeroColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                metrics!.unavailableReason ?? 'Backend metrics currently unavailable',
                style: const TextStyle(
                  color: FeroColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final total = metrics?.totalStaged?.toString() ?? (isLoading ? '...' : '0');
    final inReview = metrics?.inReviewCount?.toString() ?? (isLoading ? '...' : '0');
    final draft = metrics?.draftCount?.toString() ?? (isLoading ? '...' : '0');
    final promoted = metrics?.promotedCount?.toString() ?? (isLoading ? '...' : '0');
    final rejected = metrics?.rejectedCount?.toString() ?? (isLoading ? '...' : '0');
    final anomalies = metrics?.anomalyCount?.toString() ?? (isLoading ? '...' : '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics_outlined, size: 16, color: FeroColors.gold),
            const SizedBox(width: 6),
            const Text(
              'OPERATIONAL METRICS',
              style: TextStyle(
                color: FeroColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            if (isLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(FeroColors.gold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.45,
          children: [
            _buildMetricCard(
              context: context,
              label: 'Total Staged',
              value: total,
              color: FeroColors.info,
              statusKey: 'ALL',
            ),
            _buildMetricCard(
              context: context,
              label: 'In Review',
              value: inReview,
              color: FeroColors.pendingReview,
              statusKey: 'IN_REVIEW',
            ),
            _buildMetricCard(
              context: context,
              label: 'Draft',
              value: draft,
              color: const Color(0xFF64FFDA),
              statusKey: 'DRAFT',
            ),
            _buildMetricCard(
              context: context,
              label: 'Promoted',
              value: promoted,
              color: FeroColors.verified,
              statusKey: 'PROMOTED',
            ),
            _buildMetricCard(
              context: context,
              label: 'Rejected',
              value: rejected,
              color: FeroColors.error,
              statusKey: 'REJECTED',
            ),
            _buildMetricCard(
              context: context,
              label: 'Anomalies',
              value: anomalies,
              color: Colors.orangeAccent,
              statusKey: 'ANOMALIES',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String label,
    required String value,
    required Color color,
    required String statusKey,
  }) {
    final isSelected = selectedStatus == statusKey;

    return InkWell(
      onTap: onSelectStatus != null ? () => onSelectStatus!(statusKey) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.22)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8) ?? Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
