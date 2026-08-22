import '../models/fd_rate.dart';

/// Configurable freshness rules for rate data
/// Provides honest labels about data age — never says "Live" without verification
class RateFreshnessService {
  /// Freshness thresholds in days
  static const int recentlyVerifiedDays = 2;
  static const int verifiedRecentlyDays = 7;
  static const int olderDataDays = 30;

  /// Get freshness label for a verification timestamp
  static RateFreshness getFreshness(DateTime? verifiedAt) {
    if (verifiedAt == null) {
      return RateFreshness.unverified;
    }
    final daysSince = DateTime.now().difference(verifiedAt).inDays;
    if (daysSince <= recentlyVerifiedDays) return RateFreshness.recentlyVerified;
    if (daysSince <= verifiedRecentlyDays) return RateFreshness.verifiedRecently;
    if (daysSince <= olderDataDays) return RateFreshness.olderData;
    return RateFreshness.verificationRequired;
  }

  /// Get freshness for an FdRate object
  static RateFreshness getRateFreshness(FdRate rate) {
    if (rate.verificationStatus == VerificationStatus.verified) {
      return getFreshness(rate.verifiedAt);
    }
    if (rate.verificationStatus == VerificationStatus.pendingReview) {
      return RateFreshness.pendingReview;
    }
    if (rate.verificationStatus == VerificationStatus.stale) {
      return RateFreshness.verificationRequired;
    }
    if (rate.verificationStatus == VerificationStatus.suspicious) {
      return RateFreshness.suspicious;
    }
    return RateFreshness.unverified;
  }
}

enum RateFreshness {
  recentlyVerified,    // 0-2 days
  verifiedRecently,    // 3-7 days
  olderData,           // 8-30 days
  verificationRequired, // 30+ days
  pendingReview,       // Not yet verified
  suspicious,          // Flagged for review
  unverified,          // No verification data
}

extension RateFreshnessDisplay on RateFreshness {
  String get label {
    switch (this) {
      case RateFreshness.recentlyVerified: return 'Recently verified';
      case RateFreshness.verifiedRecently: return 'Verified recently';
      case RateFreshness.olderData: return 'Older data — verify with bank';
      case RateFreshness.verificationRequired: return 'Verification required';
      case RateFreshness.pendingReview: return 'Pending review';
      case RateFreshness.suspicious: return 'Under review';
      case RateFreshness.unverified: return 'Unverified';
    }
  }

  String get icon {
    switch (this) {
      case RateFreshness.recentlyVerified: return '✓';
      case RateFreshness.verifiedRecently: return '✓';
      case RateFreshness.olderData: return '⚠';
      case RateFreshness.verificationRequired: return '⚠';
      case RateFreshness.pendingReview: return '⏳';
      case RateFreshness.suspicious: return '⚠';
      case RateFreshness.unverified: return '—';
    }
  }
}
