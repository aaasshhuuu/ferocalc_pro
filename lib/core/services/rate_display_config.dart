/// FeroCalc Version 1.0.0 — Launch Safety Configuration
///
/// Controls the visibility of live bank rate displays across the application.
/// Ensures that unverified, stale, or preliminary interest rates are never
/// presented as current official rates.
class RateDisplayConfig {
  /// Flag controlling whether live bank rate tables, cards, and comparison lists
  /// are rendered in the application.
  ///
  /// Set to `false` for Version 1.0.0 launch-safe production release.
  /// Rate displays will be re-enabled once the Supabase staging-to-production
  /// promotion pipeline completes official attestation.
  static const bool isLiveRateDisplayEnabled = false;

  /// Canonical user-facing notice required for all unverified rate displays.
  static const String verificationPendingMessage =
      'Official bank rates are being verified and will be available in a future update.';

  /// Detailed explanation text for audit transparency.
  static const String verificationPendingSubtext =
      'Our automated rate ingestion and attestation pipeline is currently auditing interest rate slabs directly from official primary bank sources. You can use our independent calculators to compute returns with any custom rate.';
}
