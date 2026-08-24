import 'package:flutter/material.dart';
import '../models/fd_rate.dart';

/// Displays a colored verification status badge.
///
/// VERIFIED → Green shield
/// PENDING_REVIEW → Amber clock
/// STALE → Grey warning
/// SUSPICIOUS → Red alert
/// REJECTED → Red X
/// ARCHIVED → Grey archive
class VerificationBadge extends StatelessWidget {
  final VerificationStatus status;
  final bool compact;

  const VerificationBadge({
    Key? key,
    required this.status,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (compact) {
      return Tooltip(
        message: config.label,
        child: Icon(config.icon, size: 16, color: config.color),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config.color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 12, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: config.color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  static _BadgeConfig _getConfig(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified:
        return _BadgeConfig(
          label: 'VERIFIED',
          icon: Icons.verified,
          color: const Color(0xFF10B981),
        );
      case VerificationStatus.pendingReview:
        return _BadgeConfig(
          label: 'PENDING REVIEW',
          icon: Icons.schedule,
          color: const Color(0xFFF59E0B),
        );
      case VerificationStatus.stale:
        return _BadgeConfig(
          label: 'STALE',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFF6B7280),
        );
      case VerificationStatus.suspicious:
        return _BadgeConfig(
          label: 'SUSPICIOUS',
          icon: Icons.error_outline,
          color: const Color(0xFFEF4444),
        );
      case VerificationStatus.rejected:
        return _BadgeConfig(
          label: 'REJECTED',
          icon: Icons.cancel_outlined,
          color: const Color(0xFFDC2626),
        );
      case VerificationStatus.archived:
        return _BadgeConfig(
          label: 'ARCHIVED',
          icon: Icons.archive_outlined,
          color: const Color(0xFF9CA3AF),
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _BadgeConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Displays freshness information for a rate.
/// Shows how old the data is in human-readable form.
class FreshnessBadge extends StatelessWidget {
  final String freshnessLabel;
  final bool isStale;

  const FreshnessBadge({
    Key? key,
    required this.freshnessLabel,
    this.isStale = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isStale
        ? const Color(0xFFEF4444)
        : const Color(0xFF6B7280);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isStale ? Icons.warning_amber_rounded : Icons.access_time,
          size: 11,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          freshnessLabel,
          style: TextStyle(fontSize: 10, color: color),
        ),
      ],
    );
  }
}
