import 'package:flutter/material.dart';

/// FeroCalc Design System
/// Centralized design tokens for consistency across the app.
///
/// Usage:
///   FeroColors.gold
///   FeroTypography.heading
///   FeroSpacing.md
///   FeroRadius.card
class FeroColors {
  FeroColors._();

  // Brand
  static const Color gold = Color(0xFFC9A96E);
  static const Color darkNavy = Color(0xFF0A1628);
  static const Color navy = Color(0xFF0D1B2A);
  static const Color cardDark = Color(0xFF0F1D2E);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Verification
  static const Color verified = Color(0xFF10B981);
  static const Color pendingReview = Color(0xFFF59E0B);
  static const Color stale = Color(0xFF9CA3AF);
  static const Color suspicious = Color(0xFFEF4444);
  static const Color rejected = Color(0xFF991B1B);

  // Text (dark theme defaults)
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB3FFFFFF); // white70
  static const Color textTertiary = Color(0x8AFFFFFF); // white54
  static const Color textDisabled = Color(0x61FFFFFF); // white38

  // Theme-aware helpers
  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : const Color(0xFF111827);

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xB3FFFFFF)
          : const Color(0xFF4B5563);

  static Color textTertiaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0x8AFFFFFF)
          : const Color(0xFF6B7280);

  static Color textDisabledOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0x61FFFFFF)
          : const Color(0xFF9CA3AF);

  static Color cardBgOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F1D2E)
          : Colors.white;

  static Color cardBorderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white10
          : const Color(0xFFE5E7EB);
}

class FeroTypography {
  FeroTypography._();

  static const TextStyle heading = TextStyle(
    fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14, fontWeight: FontWeight.normal, height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.normal, height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.normal, height: 1.3,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2,
    color: FeroColors.gold,
  );

  static const TextStyle rate = TextStyle(
    fontSize: 22, fontWeight: FontWeight.bold,
  );
}

class FeroSpacing {
  FeroSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets screenPadding = EdgeInsets.all(16);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
}

class FeroRadius {
  FeroRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double card = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double circle = 100;

  static BorderRadius get cardBorder => BorderRadius.circular(card);
  static BorderRadius get buttonBorder => BorderRadius.circular(md);
}

class FeroShadows {
  FeroShadows._();

  static List<BoxShadow> get cardLight => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get none => [];
}

/// Standard animation durations with reduced-motion support
class FeroAnimations {
  FeroAnimations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  /// Respects platform reduced-motion preferences
  static Duration duration(BuildContext context, Duration normalDuration) {
    final prefersReduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return prefersReduced ? Duration.zero : normalDuration;
  }

  static Duration fastOf(BuildContext context) => duration(context, fast);
  static Duration normalOf(BuildContext context) => duration(context, normal);
  static Duration slowOf(BuildContext context) => duration(context, slow);
}

/// Centralized empty/loading/error state widgets (Theme-aware & Accessible)
class FeroStates {
  FeroStates._();

  /// Loading state with gold spinner and semantic announcement
  static Widget loading({String? message}) {
    return Builder(
      builder: (context) {
        final textTertiary = FeroColors.textTertiaryOf(context);
        return Semantics(
          liveRegion: true,
          label: message ?? 'Loading content, please wait',
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(FeroColors.gold),
                  strokeWidth: 2.5,
                ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: FeroTypography.bodySmall.copyWith(color: textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Empty state (Theme-adaptive with accessible labels and minimum touch targets)
  static Widget empty({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    return Builder(
      builder: (context) {
        final textSecondary = FeroColors.textSecondaryOf(context);
        final textTertiary = FeroColors.textTertiaryOf(context);
        final textDisabled = FeroColors.textDisabledOf(context);

        return Semantics(
          container: true,
          liveRegion: true,
          label: '$title${subtitle != null ? ". $subtitle" : ""}',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: textDisabled),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: FeroTypography.subheading.copyWith(color: textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: FeroTypography.bodySmall.copyWith(color: textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                      child: OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(retryLabel),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FeroColors.gold,
                          minimumSize: const Size(88, 48),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Error state (Theme-adaptive with accessible retry affordance)
  static Widget error({
    String title = 'Something went wrong',
    String? subtitle,
    VoidCallback? onRetry,
  }) {
    return Builder(
      builder: (context) {
        final textSecondary = FeroColors.textSecondaryOf(context);
        final textTertiary = FeroColors.textTertiaryOf(context);

        return Semantics(
          container: true,
          liveRegion: true,
          label: 'Error: $title${subtitle != null ? ". $subtitle" : ""}',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: FeroColors.error),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: FeroTypography.subheading.copyWith(color: textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: FeroTypography.bodySmall.copyWith(color: textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FeroColors.gold,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(88, 48),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Data unavailable state (for financial data)
  static Widget dataUnavailable({
    String title = 'Data Unavailable',
    String? subtitle,
    VoidCallback? onRetry,
  }) {
    return empty(
      icon: Icons.signal_wifi_off_rounded,
      title: title,
      subtitle: subtitle ?? 'This data requires a verified source and is not currently available.',
      onRetry: onRetry,
      retryLabel: 'Check Status',
    );
  }
}

/// Accessible status indicator that never conveys state through color alone.
/// Always pairs a distinctive icon + clear text label + semantic description.
enum FeroDataStatus {
  verified,
  pendingReview,
  unavailable,
  catalogOnly,
  stale,
}

class FeroStatusIndicator extends StatelessWidget {
  const FeroStatusIndicator({
    super.key,
    required this.status,
    this.compact = false,
  });

  final FeroDataStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, semanticDescription) = switch (status) {
      FeroDataStatus.verified => (
          Icons.verified_rounded,
          'Verified',
          FeroColors.verified,
          'Officially verified from primary bank disclosure',
        ),
      FeroDataStatus.pendingReview => (
          Icons.schedule_rounded,
          'Pending Review',
          FeroColors.pendingReview,
          'Rate candidate currently pending reviewer approval',
        ),
      FeroDataStatus.unavailable => (
          Icons.cloud_off_rounded,
          'Unavailable',
          FeroColors.error,
          'Rate data temporarily unavailable from source',
        ),
      FeroDataStatus.catalogOnly => (
          Icons.info_outline_rounded,
          'Catalog Only',
          FeroColors.info,
          'Institution metadata active; live rates not published',
        ),
      FeroDataStatus.stale => (
          Icons.history_rounded,
          'Review Needed',
          FeroColors.stale,
          'Historical rate requiring recertification',
        ),
    };

    return Semantics(
      label: 'Status: $label. $semanticDescription',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(FeroRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standardized Indian financial formatting utilities
class FeroFormatters {
  FeroFormatters._();

  /// Formats currency with INR symbol, handling positive and negative values cleanly.
  static String formatInr(num amount, {bool compact = false}) {
    final isNegative = amount < 0;
    final absVal = amount.abs();

    if (compact) {
      if (absVal >= 10000000) {
        final cr = absVal / 10000000;
        return '${isNegative ? "- " : ""}₹${cr.toStringAsFixed(cr.truncateToDouble() == cr ? 0 : 2)} Cr';
      }
      if (absVal >= 100000) {
        final lk = absVal / 100000;
        return '${isNegative ? "- " : ""}₹${lk.toStringAsFixed(lk.truncateToDouble() == lk ? 0 : 2)} L';
      }
    }

    final parts = absVal.toStringAsFixed(0);
    final buffer = StringBuffer();
    final len = parts.length;

    if (len <= 3) {
      buffer.write(parts);
    } else {
      buffer.write(parts.substring(0, len - 3));
      final lastThree = parts.substring(len - 3);
      final remaining = buffer.toString();
      buffer.clear();

      int count = 0;
      for (int i = remaining.length - 1; i >= 0; i--) {
        buffer.write(remaining[i]);
        count++;
        if (count == 2 && i > 0) {
          buffer.write(',');
          count = 0;
        }
      }
      final reversed = buffer.toString().split('').reversed.join();
      buffer.clear();
      buffer.write('$reversed,$lastThree');
    }

    return '${isNegative ? "- " : ""}₹$buffer';
  }

  /// Screen-reader friendly description of an INR amount
  static String semanticInr(num amount) {
    final isNegative = amount < 0;
    final formatted = formatInr(amount.abs());
    return isNegative ? 'Negative $formatted' : formatted;
  }

  /// Annual interest rate notation: e.g., "7.50% p.a."
  static String formatRate(double rate) => '${rate.toStringAsFixed(2)}% p.a.';

  /// Screen-reader friendly description of an annual interest rate
  static String semanticRate(double rate) =>
      '${rate.toStringAsFixed(2)} percent per annum';
}
