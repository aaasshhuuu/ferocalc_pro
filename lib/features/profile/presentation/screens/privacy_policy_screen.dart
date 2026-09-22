import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _lastUpdated = 'September 21, 2026';
  static const String _contactEmail = 'ferocalc.app@gmail.com';

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
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Last updated: $_lastUpdated',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 1. Introduction
                _sectionHeading('1. Introduction', h2Style),
                const SizedBox(height: 8),
                Text(
                  'FeroCalc ("the App") is a financial calculator application '
                  'for Fixed Deposits, Recurring Deposits, SIP, EMI, and other '
                  'financial planning tools. This Privacy Policy explains how '
                  'the App handles information when you use it.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'FeroCalc is designed with privacy in mind. The App performs '
                  'all financial calculations locally on your device and does '
                  'not require you to create an account or provide personal '
                  'information to use its core features.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 2. Information We Collect
                _sectionHeading('2. Information We Collect', h2Style),
                const SizedBox(height: 8),
                Text(
                  'FeroCalc does not transmit any personally identifiable '
                  'information (such as your name, phone number, address, or '
                  'financial account details) to any server or third party. '
                  'However, certain data is stored locally on your device as '
                  'described below.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 12),
                _subHeading(
                  'Financial Calculator Inputs',
                  h3Style,
                ),
                const SizedBox(height: 4),
                Text(
                  'All amounts, interest rates, tenures, and other values you '
                  'enter into the calculators are processed entirely on your '
                  'device in memory. These inputs are never stored on disk, '
                  'transmitted to any server, or shared with any third party.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 12),
                _subHeading(
                  'Locally Stored Data',
                  h3Style,
                ),
                const SizedBox(height: 4),
                Text(
                  'The App stores a small amount of data on your device '
                  'using local storage (SharedPreferences):',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                _bulletList(bodyStyle, [
                  'Your selected customer type (Regular or Senior Citizen), '
                      'used to show relevant interest rates.',
                  'Theme preference (dark or light mode).',
                  'If you use the login feature, your email address is stored '
                      'locally on your device for session purposes. This email '
                      'is not transmitted to any server.',
                  'A cached copy of publicly available bank interest rate data, '
                      'to allow offline access.',
                ]),
                const SizedBox(height: 8),
                Text(
                  'All of this data is stored locally on your device only and '
                  'is never transmitted to any external server operated by '
                  'FeroCalc.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 3. How We Use Information
                _sectionHeading('3. How We Use Information', h2Style),
                const SizedBox(height: 8),
                Text(
                  'The locally stored preferences described above are used '
                  'solely to:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                _bulletList(bodyStyle, [
                  'Display interest rates relevant to your customer type.',
                  'Remember your preferred visual theme.',
                  'Provide faster loading of bank rate data you have previously '
                      'viewed.',
                ]),
                const SizedBox(height: 28),

                // 4. Bank Rate Data
                _sectionHeading('4. Bank Rate Data', h2Style),
                const SizedBox(height: 8),
                Text(
                  'The App fetches publicly available bank interest rate '
                  'information from its backend server to display current FD '
                  'and RD rates. These requests are anonymous — no personal '
                  'data, device identifiers, or user-specific information is '
                  'sent with these requests. Only non-personal query filters '
                  '(such as tenure duration or customer type category) are '
                  'included.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 5. Advertising — Google AdMob
                _sectionHeading('5. Advertising — Google AdMob', h2Style),
                const SizedBox(height: 8),
                Text(
                  'The App displays banner advertisements on the Home screen '
                  '(Android only) using the Google Mobile Ads SDK (AdMob).',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'FeroCalc itself does not collect any personal data for '
                  'advertising purposes. However, the Google Mobile Ads SDK, '
                  'as a third-party service integrated into the App, may '
                  'automatically collect and process certain information as '
                  'part of ad delivery, including:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                _bulletList(bodyStyle, [
                  'Device identifiers (such as the Android Advertising ID).',
                  'IP address.',
                  'Device and hardware information (model, OS version, screen '
                      'size).',
                  'Ad interaction data (impressions, clicks).',
                ]),
                const SizedBox(height: 8),
                Text(
                  'This data is collected and processed by Google according to '
                  'Google\'s Privacy Policy. You can learn more at:',
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
                  'You can manage your ad personalization preferences through '
                  'your device\'s Settings > Google > Ads, or by visiting '
                  'Google\'s Ad Settings page.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 6. Third-Party Services
                _sectionHeading('6. Third-Party Services', h2Style),
                const SizedBox(height: 8),
                Text(
                  'In addition to Google AdMob described above, the App uses '
                  'the following third-party services:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                _bulletList(bodyStyle, [
                  'Google Fonts — The App downloads the Inter typeface from '
                      'Google\'s font servers at runtime for display purposes.',
                  'Share functionality — When you choose to share a calculation '
                      'result, the App uses your device\'s built-in share sheet. '
                      'Data is only sent to external apps that you explicitly '
                      'select.',
                ]),
                const SizedBox(height: 8),
                Text(
                  'The App does not use any analytics, crash reporting, push '
                  'notification, or tracking services.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 7. Data Storage and Retention
                _sectionHeading('7. Data Storage and Retention', h2Style),
                const SizedBox(height: 8),
                Text(
                  'All user preferences and cached data are stored locally on '
                  'your device. No user data is stored on any remote server '
                  'operated by FeroCalc.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can clear all locally stored data at any time by:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                _bulletList(bodyStyle, [
                  'Clearing the App\'s data through your device\'s '
                      'Settings > Apps > FeroCalc > Storage > Clear Data.',
                  'Uninstalling the App, which removes all locally stored data.',
                ]),
                const SizedBox(height: 28),

                // 8. Data Security
                _sectionHeading('8. Data Security', h2Style),
                const SizedBox(height: 8),
                Text(
                  'Since FeroCalc does not collect or transmit personal data, '
                  'the primary security consideration is the data stored '
                  'locally on your device. Local preferences are stored using '
                  'standard platform storage mechanisms. Network requests to '
                  'fetch bank rate data are made over HTTPS.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 9. Children's Privacy
                _sectionHeading('9. Children\'s Privacy', h2Style),
                const SizedBox(height: 8),
                Text(
                  'FeroCalc is a general-purpose financial calculator. It does '
                  'not target children under the age of 13 and does not '
                  'knowingly collect any personal information from children.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 10. Changes to This Privacy Policy
                _sectionHeading(
                  '10. Changes to This Privacy Policy',
                  h2Style,
                ),
                const SizedBox(height: 8),
                Text(
                  'We may update this Privacy Policy from time to time. Any '
                  'changes will be reflected in the App and on this page with '
                  'an updated "Last updated" date. We encourage you to review '
                  'this Privacy Policy periodically.',
                  style: bodyStyle,
                ),
                const SizedBox(height: 28),

                // 11. Contact Us
                _sectionHeading('11. Contact Us', h2Style),
                const SizedBox(height: 8),
                Text(
                  'If you have any questions or concerns about this Privacy '
                  'Policy, please contact us at:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _contactEmail,
                  style: bodyStyle?.copyWith(
                    color: headingColor,
                    fontWeight: FontWeight.w600,
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
                  Text('•  ',
                      style: style?.copyWith(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(item, style: style)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
