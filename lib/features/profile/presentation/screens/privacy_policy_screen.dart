import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy Policy', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Last updated: August 2026', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            _section('Information We Collect', 'FeroCalc does not collect, store, or share any personal information. All calculations are performed locally on your device. No account or registration is required to use the app.'),
            _section('Data Storage', 'All your preferences (such as theme settings) are stored locally on your device and are never transmitted to any server.'),
            _section('Third-Party Services', 'FeroCalc may display advertisements through Google AdMob. Google may collect certain data as described in their privacy policy. We recommend reviewing Google\'s Privacy Policy for more information.'),
            _section('Bank Rate Data', 'Bank rates and market data shown in the app are sourced from publicly available information and are provided for informational purposes only. We do not guarantee the accuracy of this data.'),
            _section('Children\'s Privacy', 'FeroCalc is a general-purpose financial calculator and does not specifically target children under 13. We do not knowingly collect data from children.'),
            _section('Changes to This Policy', 'We may update this Privacy Policy from time to time. Changes will be reflected in the app with an updated date.'),
            _section('Contact Us', 'If you have questions about this Privacy Policy, please contact us at ferocalc.app@gmail.com'),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }
}
