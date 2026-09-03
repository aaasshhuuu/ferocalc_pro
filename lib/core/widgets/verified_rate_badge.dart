/// FeroCalc Verified FD Rate Engine
/// Verification badge for Supabase-backed VerifiedFdRate objects — Phase K
///
/// This file supplements (does NOT replace) the existing verification_badge.dart.
/// The existing badge handles legacy FdRate / VerificationStatus enums.
/// This new badge handles the new VerifiedFdRate from Supabase.
///
/// RULE: VERIFIED and PENDING_REVIEW must never share the same visual treatment.

import 'package:flutter/material.dart';
import '../models/verified_fd_rate.dart';

// ============================================================
// VerifiedRateBadge
// Compact chip for a VerifiedFdRate from Supabase.
// ============================================================

class VerifiedRateBadge extends StatelessWidget {
  final bool showLabel;

  const VerifiedRateBadge({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF052E16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF16A34A), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF22C55E)),
          if (showLabel) ...[
            const SizedBox(width: 4),
            const Text(
              'Verified',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF22C55E),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// PendingReviewRateBadge
// Shown for legacy / unverified rates.
// Intentionally distinct from VerifiedRateBadge in every visual dimension.
// ============================================================

class PendingReviewRateBadge extends StatelessWidget {
  const PendingReviewRateBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          'This rate has not been verified against an official bank source. '
          'Do not use for financial decisions without independent verification.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF78350F).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF59E0B).withOpacity(0.4),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFF59E0B)),
            SizedBox(width: 4),
            Text(
              'Pending Review',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF59E0B),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// VerifiedRateDetailPanel
// Expanded verification info for the bank detail screen.
// ============================================================

class VerifiedRateDetailPanel extends StatelessWidget {
  final VerifiedFdRate rate;

  const VerifiedRateDetailPanel({super.key, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF22C55E).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, size: 16, color: Color(0xFF22C55E)),
              SizedBox(width: 6),
              Text(
                '✓ Verified',
                style: TextStyle(
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _row('Source', rate.bankName),
          if (rate.verifiedAt != null)
            _row('Verified', _formatDate(rate.verifiedAt!)),
          _row('Effective From', _formatDate(rate.effectiveFrom)),
          if (rate.effectiveUntil != null)
            _row('Valid Until', _formatDate(rate.effectiveUntil!)),
          _row('Compounding', rate.compoundingFrequency.displayLabel),
          _row(
            'Product Type',
            rate.isCallable
                ? 'Standard (premature withdrawal allowed)'
                : 'Non-callable (higher rate, no early exit)',
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFE5E7EB),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
