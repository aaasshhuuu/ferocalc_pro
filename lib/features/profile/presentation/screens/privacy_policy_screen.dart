import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _lastUpdated = 'November 12, 2026';
  static const String _contactEmail = 'ferocalc.app@gmail.com';
  static const String _publisherPlaceholder = '[PUBLISHER_LEGAL_ENTITY_NAME]';
  static const String _addressPlaceholder = '[PUBLISHER_REGISTERED_ADDRESS]';

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
    final h3Style = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Privacy Policy',
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
                    'Last updated: $_lastUpdated | Effective Date: November 12, 2026',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 1. Introduction & Overview
                _sectionHeading('1. Introduction & Overview', h2Style),
                const SizedBox(height: 8),
                Text(
                  'FeroCalc ("the App", "we", "us") is an independent financial calculator, '
                  'fixed deposit (FD) rate discovery, and financial literacy application designed '
                  'for users in India. We are committed to transparency and user privacy.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'FeroCalc is NOT a bank, Non-Banking Financial Company (NBFC), credit broker, '
                  'or deposit-taking entity. We do not originate loans, accept customer deposits, '
                  'or connect to consumer bank accounts. You can use all core calculator and rate '
                  'discovery features without creating an account or providing personal identity.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 2. Data Storage & Transmission Inventory
                _sectionHeading('2. Data Storage & Transmission Architecture', h2Style),
                const SizedBox(height: 8),
                Text(
                  'To ensure complete transparency, here is an exact accounting of what data stays '
                  'locally on your device and what data may be transmitted over network connections:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 12),
                _subHeading('A. Data Processed and Stored Strictly Locally (On-Device)', h3Style),
                const SizedBox(height: 6),
                _bulletList(bodyStyle, [
                  'Financial Calculator Inputs: Loan principals, interest rates, tenures, and compounding frequencies are evaluated in-memory and never sent off-device.',
                  'Calculation History: Calculations you choose to save are stored in your device\'s private storage (SharedPreferences) and are never uploaded.',
                  'Financial Goals: Custom financial targets created in Goal Planner are kept exclusively in local device storage.',
                  'Financial Insights Profile: Income, expense, emergency fund, and retirement metrics entered into the Financial Insights dashboard are strictly stored locally on your device. FeroCalc servers never receive or store your financial figures.',
                  'App Preferences: Visual theme (Dark/Light mode) and customer category selection (Regular or Senior Citizen) are stored on-device only.',
                  'Backup Privacy Isolation: Sensitive financial profile data and anonymous credentials in SharedPreferences are excluded from cloud backup to ensure personal figures are not transmitted to cloud storage providers.',
                ]),
                const SizedBox(height: 12),
                _subHeading('B. Data Transmitted to Backend APIs', h3Style),
                const SizedBox(height: 6),
                _bulletList(bodyStyle, [
                  'Public Verified Rate Queries: When searching or comparing bank FD rates, anonymous read-only HTTPS requests fetch verified public rate tables from our backend. No user profile, device ID, or account token is sent with these queries. Request metadata is processed transiently by hosting infrastructure (Vercel) according to standard operational policies.',
                  'Anonymous Installation Identifier: If you use the notifications feature, an anonymous installation ID generated by the App (e.g., inst_xxx) is sent to our notification endpoint to register for verified rate change alerts. This identifier is NOT linked to your name, phone number, email, IMEI, or Google account.',
                  'Favorite Bank Preferences: If you mark banks as favorites and enable notifications, the list of favorite bank IDs (e.g. ["sbi", "hdfc"]) is synchronized to receive relevant rate updates.',
                  'Notification Preference Flags: Category toggles (e.g. significant rate changes, newly promoted slabs) are synchronized with the notification service.',
                ]),
                const SizedBox(height: 28),

                // 3. Third-Party Services & Advertising (Google AdMob)
                _sectionHeading('3. Advertising & Third-Party SDKs', h2Style),
                const SizedBox(height: 8),
                Text(
                  'FeroCalc is supported by banner advertising delivered via Google AdMob (Google Mobile Ads SDK, '
                  'specifically com.google.android.gms:play-services-ads:25.4.0) on the Android Home screen.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'FeroCalc itself does not sell your data or collect personal information for advertising. '
                  'However, Google AdMob, as a third-party advertising SDK, automatically collects and '
                  'processes certain data under Google\'s Privacy Policy for ad serving, analytics, and fraud prevention:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                _bulletList(bodyStyle, [
                  'Device and Account Identifiers: Google Advertising ID (GAID), App Set ID, and device identifiers.',
                  'Approximate Location: Derived from IP address for general geographic location estimation (country and city) and regional ad delivery. FeroCalc declares zero GPS or fine location permissions.',
                  'Product Interactions: App launches, screen views, ad impressions, and ad click/tap events.',
                  'Diagnostic & Performance Information: SDK startup time, latency, battery level, device volume, connection types, crashes, and ANR telemetry.',
                ]),
                const SizedBox(height: 8),
                Text(
                  'AdMob policies and privacy information can be reviewed at:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  'https://policies.google.com/privacy',
                  style: bodyStyle?.copyWith(
                    color: headingColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Managing Your Ad Choices: You can reset or delete your Advertising ID at any time '
                  'through your Android device: Settings > Google > Ads > Reset advertising ID (or Delete advertising ID).',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 4. Financial Services Policy & Disclaimer
                _sectionHeading('4. Financial Non-Affiliation & Calculator Transparency', h2Style),
                const SizedBox(height: 8),
                Text(
                  '• FeroCalc is an independent utility. It is not affiliated with, endorsed by, or operating on behalf of the Reserve Bank of India (RBI) or any commercial or small finance bank.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  '• Calculator results are mathematical estimates based on user-supplied numbers and standard compounding formulas. They do not represent guaranteed returns or binding quotes.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  '• Bank FD rates displayed in the Discovery section are gathered from publicly published bank circulars and official websites. Rates are subject to change by respective banks without notice. Users must verify all rate terms directly with the bank before placing deposits.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 5. User Accounts & Data Deletion Rights
                _sectionHeading('5. User Accounts & Data Deletion Rights', h2Style),
                const SizedBox(height: 8),
                Text(
                  'Consumer Accounts Policy: FeroCalc does NOT require or offer consumer account creation. You do not register an email, username, or profile on our servers to calculate finances or browse verified bank rates. Therefore, account deletion workflows are not applicable.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Data Deletion Request Mechanism: If you enabled notifications, an anonymous installation ID, device push token, and alert preferences may be stored remotely on FeroCalc servers. You have complete control to request deletion of this data:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                _bulletList(bodyStyle, [
                  'Self-Service In-App Deletion: Navigate to Notification Settings > Data Privacy & Deletion > Tap "Delete Remote Notification Data". This securely revokes your device token and deletes all remote notification preferences using a cryptographic installation auth token. Your local calculations, goals, and financial profiles remain intact.',
                  'Email Deletion Requests: If you have uninstalled the application or prefer assisted deletion, email ferocalc.app@gmail.com with your anonymous Installation ID. We will purge your device registration record within 30 days.',
                  'Retained Operational Data: Shared verified rate history, public bank circular metadata, and system security audit records are retained permanently to ensure public rate auditability, regulatory compliance, and platform security.',
                  'Local On-Device Data Clearing: To delete local saved calculations, goals, and financial profiles, use Profile > Data & Trust > Clear Local Cache / Reset Data, or use Android Settings > Apps > FeroCalc > Storage > Clear Storage.',
                ]),
                const SizedBox(height: 28),

                // 6. Data Security Practices
                _sectionHeading('6. Data Security Practices', h2Style),
                const SizedBox(height: 8),
                Text(
                  'We take comprehensive administrative, architectural, and technical precautions to safeguard data:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                _bulletList(bodyStyle, [
                  'Encryption in Transit: All API network calls to FeroCalc backend services use modern TLS/HTTPS encryption.',
                  'Cleartext Traffic Blocked: The Android application explicitly blocks unencrypted cleartext HTTP traffic (usesCleartextTraffic="false").',
                  'Cloud Backup Privacy Isolation: The application\'s SharedPreferences storage is explicitly excluded from Android Cloud Backup (data_extraction_rules.xml and backup_rules.xml). This guarantees that sensitive personal financial profiles, goals, calculation history, and administrative credentials are never uploaded to cloud storage providers or transferred unencrypted.',
                  'Principle of Least Privilege: Administrative rate management routes are protected by multi-factor authentication, cryptographic tokens, and strict Role-Based Access Controls (RBAC). Consumer client builds contain zero administrative credentials.',
                  'Fail-Closed Architecture: Rate changes are only displayed to users once verified through documented human reviewer verification or strict multi-source pipeline checks.',
                ]),
                const SizedBox(height: 28),

                // 7. Children's Privacy
                _sectionHeading('7. Children\'s Privacy', h2Style),
                const SizedBox(height: 8),
                Text(
                  'FeroCalc is intended for adult consumers managing personal finances in India. '
                  'We do not knowingly collect personal data from children under the age of 18 (or 13 where applicable). '
                  'If you believe a child has provided us with personal information, please contact us immediately.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 8. Contact Information
                _sectionHeading('8. Developer Contact & Publisher Details', h2Style),
                const SizedBox(height: 8),
                Text(
                  'If you have questions, feedback, or privacy inquiries regarding FeroCalc, please contact us at:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  'Email: $_contactEmail',
                  style: bodyStyle?.copyWith(
                    color: headingColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Publisher: $_publisherPlaceholder\n'
                  'Registered Address: $_addressPlaceholder',
                  style: bodyStyle?.copyWith(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(String text, TextStyle? style) {
    return Text(text, style: style);
  }

  Widget _subHeading(String text, TextStyle? style) {
    return Text(text, style: style);
  }

  Widget _bulletList(TextStyle? style, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•  ',
                    style: style?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(item, style: style)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
