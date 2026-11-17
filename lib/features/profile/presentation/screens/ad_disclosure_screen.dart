import 'package:flutter/material.dart';

class AdDisclosureScreen extends StatelessWidget {
  const AdDisclosureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headingColor = theme.colorScheme.primary;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.7,
      fontSize: 14,
    );
    final h2Style = theme.textTheme.titleLarge?.copyWith(
      color: headingColor,
      fontWeight: FontWeight.w700,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Advertising Disclosures')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Advertising & Monetization Disclosures',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Transparency in Advertising and Editorial Independence',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                _section(
                  '1. How FeroCalc Is Funded',
                  'FeroCalc is offered to users free of charge. To cover infrastructure, ongoing data verification pipelines, server hosting, and app development costs, we display banner advertisements provided by Google AdMob on the Android Home screen.',
                  h2Style,
                  bodyStyle,
                ),

                _section(
                  '2. Clear Visual Separation of Advertisements',
                  'All advertisements in FeroCalc are strictly labeled with an "ADVERTISEMENT" badge and enclosed within dedicated containers. Advertisements are never styled or formatted to mimic calculator results, bank fixed deposit rate cards, system alerts, or navigation buttons. We adhere strictly to Google Play and Google AdMob placement policies to prevent accidental clicks.',
                  h2Style,
                  bodyStyle,
                ),

                _section(
                  '3. Non-Intrusive Ad Experience',
                  'FeroCalc does not show intrusive interstitial popups, full-screen ads during financial calculations, or rewarded video walls before viewing calculator results. Financial form entry and calculations remain focused and uninterrupted.',
                  h2Style,
                  bodyStyle,
                ),

                _section(
                  '4. Editorial Independence & Zero Sponsored Rank Manipulation',
                  'Bank rankings, rate comparisons, and Smart Discovery recommendations in FeroCalc are determined entirely by mathematical interest rates, verified tenure criteria, and official bank schedules. No financial institution pays to artificially elevate its ranking, bias calculator results, or receive preferential placement. Listings are purely objective and data-driven.',
                  h2Style,
                  bodyStyle,
                ),

                _section(
                  '5. Third-Party Data Collection by Google AdMob',
                  'FeroCalc does not sell your personal information. When an ad is displayed, Google Mobile Ads SDK may automatically process diagnostic data, IP addresses (for coarse geographic ad delivery), and the Google Advertising ID (GAID) in accordance with Google\'s Privacy Policy.\n\nYou can manage ad personalization or reset your advertising identifier at any time via your device settings: Android Settings > Google > Ads.',
                  h2Style,
                  bodyStyle,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(
    String title,
    String body,
    TextStyle? titleStyle,
    TextStyle? bodyStyle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: 8),
          Text(body, style: bodyStyle),
        ],
      ),
    );
  }
}
