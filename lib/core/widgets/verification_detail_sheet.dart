import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/fd_rate.dart';
import '../services/rate_freshness_service.dart';

/// Shows a bottom sheet explaining the verification status of a rate.
/// Tappable from any VerificationBadge.
class VerificationDetailSheet {
  static void show(BuildContext context, FdRate rate, {String? bankName}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = const Color(0xFFC9A96E);
    final freshness = RateFreshnessService.getRateFreshness(rate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Rate Verification Details',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (bankName != null) ...[
              const SizedBox(height: 4),
              Text(bankName, style: TextStyle(fontSize: 14, color: gold)),
            ],
            const SizedBox(height: 20),

            // Status row
            _buildRow(
              context, 'Verification Status',
              _statusLabel(rate.verificationStatus),
              _statusColor(rate.verificationStatus),
              icon: _statusIcon(rate.verificationStatus),
            ),
            const SizedBox(height: 12),

            // Why this status
            _buildExplanation(context, rate),
            const SizedBox(height: 16),

            // Freshness
            _buildRow(
              context, 'Data Freshness',
              freshness.label,
              _freshnessColor(freshness),
            ),
            const SizedBox(height: 12),

            // Verification date
            if (rate.verifiedAt != null) ...[
              _buildRow(
                context, 'Last Verified',
                _formatDate(rate.verifiedAt!),
                null,
              ),
              const SizedBox(height: 12),
            ],

            // Effective dates
            if (rate.effectiveFrom != null) ...[
              _buildRow(
                context, 'Effective From',
                _formatDate(rate.effectiveFrom!),
                null,
              ),
              const SizedBox(height: 12),
            ],
            if (rate.effectiveUntil != null) ...[
              _buildRow(
                context, 'Effective Until',
                _formatDate(rate.effectiveUntil!),
                null,
              ),
              const SizedBox(height: 12),
            ],

            // Source
            if (rate.sourceUrl != null && rate.sourceUrl!.isNotEmpty) ...[
              _buildSourceRow(context, rate),
              const SizedBox(height: 12),
            ],

            // Rate details
            _buildRow(context, 'Interest Rate', '${rate.interestRate.toStringAsFixed(2)}% p.a.', null),
            const SizedBox(height: 12),
            _buildRow(context, 'Tenure', rate.tenureDescription, null),
            const SizedBox(height: 12),
            _buildRow(context, 'Customer Type', _customerTypeLabel(rate.customerType), null),

            const SizedBox(height: 20),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.08 : 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This rate has not been independently verified. '
                      'Please confirm with the bank before making financial decisions.',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Widget _buildRow(BuildContext context, String label, String value, Color? valueColor, {IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: valueColor ?? (isDark ? Colors.white54 : Colors.black54)),
          const SizedBox(width: 8),
        ],
        Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  static Widget _buildExplanation(BuildContext context, FdRate rate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String explanation;

    switch (rate.verificationStatus) {
      case VerificationStatus.verified:
        explanation = 'This rate has been independently verified against an official bank source.';
        break;
      case VerificationStatus.pendingReview:
        explanation = 'This rate is from static data and has not yet been verified against the bank\'s current published rates. It may be outdated.';
        break;
      case VerificationStatus.stale:
        explanation = 'This rate was previously verified but the verification has expired. The bank may have updated their rates since.';
        break;
      case VerificationStatus.suspicious:
        explanation = 'This rate change triggered an anomaly check. It is under review to confirm whether it is accurate.';
        break;
      case VerificationStatus.rejected:
        explanation = 'This rate has been determined to be incorrect and should not be relied upon.';
        break;
      case VerificationStatus.archived:
        explanation = 'This rate is historical and no longer current. It is kept for reference only.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, size: 16, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              explanation,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSourceRow(BuildContext context, FdRate rate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = const Color(0xFFC9A96E);
    final isVerifiedSource = rate.verificationStatus == VerificationStatus.verified;
    final sourceLabel = isVerifiedSource ? 'Official Bank Source' : 'Source: Bank Website (Unverified)';

    return Row(
      children: [
        Icon(Icons.link, size: 16, color: isDark ? Colors.white54 : Colors.black54),
        const SizedBox(width: 8),
        Text('Source', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final url = rate.sourceUrl;
            if (url != null && url.isNotEmpty) {
              final uri = Uri.tryParse(url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sourceLabel,
                style: TextStyle(fontSize: 12, color: gold, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Icon(Icons.open_in_new, size: 12, color: gold),
            ],
          ),
        ),
      ],
    );
  }

  static String _statusLabel(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified: return 'Verified';
      case VerificationStatus.pendingReview: return 'Pending Review';
      case VerificationStatus.stale: return 'Stale';
      case VerificationStatus.suspicious: return 'Under Review';
      case VerificationStatus.rejected: return 'Rejected';
      case VerificationStatus.archived: return 'Archived';
    }
  }

  static IconData _statusIcon(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified: return Icons.verified;
      case VerificationStatus.pendingReview: return Icons.schedule;
      case VerificationStatus.stale: return Icons.warning_amber;
      case VerificationStatus.suspicious: return Icons.error_outline;
      case VerificationStatus.rejected: return Icons.cancel;
      case VerificationStatus.archived: return Icons.archive;
    }
  }

  static Color _statusColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified: return const Color(0xFF10B981);
      case VerificationStatus.pendingReview: return const Color(0xFFF59E0B);
      case VerificationStatus.stale: return Colors.grey;
      case VerificationStatus.suspicious: return const Color(0xFFEF4444);
      case VerificationStatus.rejected: return const Color(0xFF991B1B);
      case VerificationStatus.archived: return Colors.grey;
    }
  }

  static Color _freshnessColor(RateFreshness freshness) {
    switch (freshness) {
      case RateFreshness.recentlyVerified: return const Color(0xFF10B981);
      case RateFreshness.verifiedRecently: return const Color(0xFF10B981);
      case RateFreshness.olderData: return const Color(0xFFF59E0B);
      case RateFreshness.verificationRequired: return Colors.grey;
      case RateFreshness.pendingReview: return const Color(0xFFF59E0B);
      case RateFreshness.suspicious: return const Color(0xFFEF4444);
      case RateFreshness.unverified: return Colors.grey;
    }
  }

  static String _customerTypeLabel(CustomerType type) {
    switch (type) {
      case CustomerType.regular: return 'Regular';
      case CustomerType.seniorCitizen: return 'Senior Citizen';
      case CustomerType.superSeniorCitizen: return 'Super Senior Citizen';
      case CustomerType.staff: return 'Staff';
      case CustomerType.nre: return 'NRE';
      case CustomerType.nro: return 'NRO';
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
