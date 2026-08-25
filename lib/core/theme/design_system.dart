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

  // Text (dark theme)
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB3FFFFFF); // white70
  static const Color textTertiary = Color(0x8AFFFFFF); // white54
  static const Color textDisabled = Color(0x61FFFFFF); // white38
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
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get none => [];
}

/// Standard animation durations
class FeroAnimations {
  FeroAnimations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
}

/// Centralized empty/loading/error state widgets
class FeroStates {
  FeroStates._();

  /// Loading state with gold spinner
  static Widget loading({String? message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(FeroColors.gold),
            strokeWidth: 2.5,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: FeroTypography.bodySmall.copyWith(color: FeroColors.textTertiary)),
          ],
        ],
      ),
    );
  }

  /// Empty state
  static Widget empty({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: FeroColors.textDisabled),
            const SizedBox(height: 16),
            Text(title, style: FeroTypography.subheading.copyWith(color: FeroColors.textSecondary), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle, style: FeroTypography.bodySmall.copyWith(color: FeroColors.textTertiary), textAlign: TextAlign.center),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel),
                style: OutlinedButton.styleFrom(foregroundColor: FeroColors.gold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Error state
  static Widget error({
    String title = 'Something went wrong',
    String? subtitle,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: FeroColors.error),
            const SizedBox(height: 16),
            Text(title, style: FeroTypography.subheading.copyWith(color: FeroColors.textSecondary), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle, style: FeroTypography.bodySmall.copyWith(color: FeroColors.textTertiary), textAlign: TextAlign.center),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FeroColors.gold,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Data unavailable state (for financial data)
  static Widget dataUnavailable({
    String title = 'Data Unavailable',
    String? subtitle,
  }) {
    return empty(
      icon: Icons.signal_wifi_off,
      title: title,
      subtitle: subtitle ?? 'This data requires a verified source and is not currently available.',
    );
  }
}
