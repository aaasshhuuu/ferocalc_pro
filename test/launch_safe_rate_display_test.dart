import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fincalc_pro/core/data/bank_rate_repository.dart';
import 'package:fincalc_pro/core/models/bank.dart';
import 'package:fincalc_pro/core/models/fd_rate.dart';
import 'package:fincalc_pro/core/services/rate_display_config.dart';
import 'package:fincalc_pro/core/widgets/fd_rate_card.dart';
import 'package:fincalc_pro/core/widgets/official_rates_notice_card.dart';
import 'package:fincalc_pro/core/widgets/result_display_card.dart';
import 'package:fincalc_pro/features/compare/presentation/screens/bank_detail_screen.dart';
import 'package:fincalc_pro/features/compare/presentation/screens/two_bank_comparison_screen.dart';

void main() {
  group('Launch Safety Rate Display Verification', () {
    test('RateDisplayConfig has live rate display disabled for launch safety', () {
      expect(RateDisplayConfig.isLiveRateDisplayEnabled, isFalse);
      expect(
        RateDisplayConfig.verificationPendingMessage,
        equals('Official bank rates are being verified and will be available in a future update.'),
      );
    });

    testWidgets('OfficialRatesNoticeCard renders canonical notice and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfficialRatesNoticeCard(
              bankName: 'State Bank of India',
              officialWebsiteUrl: 'https://sbi.co.in',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Official bank rates are being verified and will be available in a future update.'),
        findsOneWidget,
      );
      expect(find.text('Open FD Calculator'), findsOneWidget);
      expect(find.text('Browse All Calculators'), findsOneWidget);
    });

    testWidgets('ResultDisplayCard displays indicative financial estimate disclaimer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResultDisplayCard(
              mainLabel: 'Total Maturity Value',
              mainValue: '\u20B91,25,000',
              details: [
                {'label': 'Principal', 'value': '\u20B91,00,000'},
                {'label': 'Interest Earned', 'value': '\u20B925,000'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Maturity Value'), findsOneWidget);
      expect(find.text('\u20B91,25,000'), findsOneWidget);
      expect(
        find.text('Indicative estimate for illustrative purposes. Actual returns or terms may vary by financial institution.'),
        findsOneWidget,
      );
    });

    testWidgets('FdRateCard hides raw interest rate when rate is unverified in launch-safe mode', (tester) async {
      final sbi = BankRateRepository.getBankById('state_bank_of_india')!;
      final unverifiedRate = FdRate(
        rateId: 'sbi_unverified_1y',
        bankId: 'state_bank_of_india',
        customerType: CustomerType.regular,
        minTenureDays: 365,
        maxTenureDays: 729,
        interestRate: 6.80,
        verificationStatus: VerificationStatus.pendingReview,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FdRateCard(
              bank: sbi,
              rate: unverifiedRate,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Raw percentage rate MUST NOT appear as current official rate
      expect(find.text('6.80% p.a.'), findsNothing);
      expect(find.text('Verification in Progress'), findsOneWidget);
      expect(
        find.text('Official bank rates are being verified and will be available in a future update.'),
        findsOneWidget,
      );
    });

    testWidgets('BankDetailScreen renders OfficialRatesNoticeCard and hides unverified rate tables', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BankDetailScreen(bankName: 'State Bank of India'),
        ),
      );
      await tester.pumpAndSettle();

      // Should display notice card
      expect(
        find.text('Official bank rates are being verified and will be available in a future update.'),
        findsOneWidget,
      );

      // Should NOT render stale rate slabs as official rates
      expect(find.text('6.80%'), findsNothing);
      expect(find.text('7.00%'), findsNothing);
    });

    testWidgets('TwoBankComparisonScreen renders OfficialRatesNoticeCard and suppresses raw comparison rates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TwoBankComparisonScreen(
            initialBankAId: 'state_bank_of_india',
            initialBankBId: 'hdfc_bank',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rates section replaced with launch-safe notice
      expect(
        find.text('Official bank rates are being verified and will be available in a future update.'),
        findsOneWidget,
      );
      expect(find.text('6.80% p.a.'), findsNothing);
      expect(find.text('6.60% p.a.'), findsNothing);
    });
  });
}
