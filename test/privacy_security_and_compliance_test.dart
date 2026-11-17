import 'dart:io';
import 'package:fincalc_pro/features/financial_insights/domain/models/financial_profile.dart';
import 'package:fincalc_pro/features/financial_insights/domain/repositories/financial_profile_repository.dart';
import 'package:fincalc_pro/features/goals/domain/repositories/goal_repository.dart';
import 'package:fincalc_pro/features/history/domain/repositories/calculation_history_repository.dart';
import 'package:fincalc_pro/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/ad_disclosure_screen.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/financial_disclaimer_screen.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/privacy_policy_screen.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/profile_screen.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/terms_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:fincalc_pro/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  group('FeroCalc Phase 5.1.0.1: Legal Accuracy & Privacy Screens Unit Tests', () {
    testWidgets('1. PrivacyPolicyScreen renders complete data inventory, AdMob SDK, and data deletion rights', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PrivacyPolicyScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy Policy'), findsAtLeastNWidgets(1));
      expect(find.text('1. Introduction & Overview'), findsOneWidget);
      expect(find.text('2. Data Storage & Transmission Architecture'), findsOneWidget);
      expect(find.text('3. Advertising & Third-Party SDKs'), findsOneWidget);
      expect(find.text('4. Financial Non-Affiliation & Calculator Transparency'), findsOneWidget);
      expect(find.text('5. User Accounts & Data Deletion Rights'), findsOneWidget);
      expect(find.text('6. Data Security Practices'), findsOneWidget);

      // Verifies honest transmission and local storage declarations
      expect(find.textContaining('Financial Calculator Inputs'), findsOneWidget);
      expect(find.textContaining('Financial Insights Profile'), findsOneWidget);
      expect(find.textContaining('Anonymous Installation Identifier'), findsOneWidget);
      expect(find.textContaining('Google AdMob'), findsAtLeastNWidgets(1));
      expect(find.textContaining('play-services-ads:25.4.0'), findsOneWidget);
      expect(find.textContaining('Product Interactions'), findsOneWidget);
      expect(find.textContaining('Diagnostic & Performance Information'), findsOneWidget);
      expect(find.textContaining('ferocalc.app@gmail.com'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Self-Service In-App Deletion'), findsOneWidget);
      expect(find.textContaining('[PUBLISHER_LEGAL_ENTITY_NAME]'), findsOneWidget);
    });

    testWidgets('2. TermsScreen renders comprehensive Terms of Use and utility disclosures', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TermsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Terms of Use'), findsAtLeastNWidgets(1));
      expect(find.text('1. Acceptance of Terms'), findsOneWidget);
      expect(find.text('2. Non-Banking, Non-Lending & Utility Nature'), findsOneWidget);
      expect(find.text('3. Calculation Results Are Mathematical Estimates'), findsOneWidget);
      expect(find.text('4. Bank Rate Information & Verification Disclaimer'), findsOneWidget);
      expect(find.text('8. Limitation of Liability'), findsOneWidget);
      expect(find.text('9. Governing Law & Jurisdiction'), findsOneWidget);

      expect(find.textContaining('NOT a bank, Non-Banking Financial Company (NBFC)'), findsOneWidget);
      expect(find.textContaining('laws of India'), findsOneWidget);
    });

    testWidgets('3. FinancialDisclaimerScreen renders updated statutory tax laws (Income-tax Act, 2025) and DICGC', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FinancialDisclaimerScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Financial & Rate Disclaimers'), findsOneWidget);
      expect(find.text('1. Educational & Calculative Estimates Only'), findsOneWidget);
      expect(find.text('2. Non-Banking, Non-Lending Notice'), findsOneWidget);
      expect(find.text('3. Bank Rate Verification & Timeliness'), findsOneWidget);
      expect(find.text('4. Senior Citizen Rates & Special Slabs'), findsOneWidget);
      expect(find.text('5. DICGC Deposit Insurance Coverage'), findsOneWidget);

      // Section 5 DICGC insurance checks
      expect(find.textContaining('₹5,00,000 (Rupees Five Lakh)'), findsOneWidget);
      expect(find.textContaining('in the same right and capacity'), findsOneWidget);
      expect(find.textContaining('separate insured banking entities are independently insured'), findsOneWidget);

      // Scroll to Section 6 Taxation and TDS Disclosures
      final section6Header = find.text('6. Taxation and TDS Disclosures');
      await tester.scrollUntilVisible(
        section6Header,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(section6Header, findsOneWidget);

      // Section 6 Tax Law accuracy checks
      expect(find.textContaining('Income-tax Act, 2025'), findsOneWidget);
      expect(find.textContaining('Section 393(1), Table Sl. No. 5(ii)'), findsOneWidget);
      expect(find.textContaining('1 April 2026'), findsOneWidget);
      expect(find.textContaining('₹1,00,000 for resident senior citizens'), findsOneWidget);
      expect(find.textContaining('₹50,000 for other individuals'), findsOneWidget);
      expect(find.textContaining('advance withholding mechanism and does NOT constitute an exemption from income tax'), findsOneWidget);
      expect(find.textContaining('up to 31 March 2026 under Section 194A of the earlier Income-tax Act, 1961'), findsOneWidget);
      expect(find.textContaining('Form 15G'), findsOneWidget);
      expect(find.textContaining('Form 15H'), findsOneWidget);
    });

    testWidgets('4. AdDisclosureScreen renders AdMob transparency and editorial independence', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AdDisclosureScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Advertising & Monetization Disclosures'), findsOneWidget);
      expect(find.text('1. How FeroCalc Is Funded'), findsOneWidget);
      expect(find.text('2. Clear Visual Separation of Advertisements'), findsOneWidget);
      expect(find.text('3. Non-Intrusive Ad Experience'), findsOneWidget);
      expect(find.text('4. Editorial Independence & Zero Sponsored Rank Manipulation'), findsOneWidget);
      expect(find.text('5. Third-Party Data Collection by Google AdMob'), findsOneWidget);
      expect(find.textContaining('ADVERTISEMENT'), findsOneWidget);
    });

    testWidgets('5. ProfileScreen renders Legal, Privacy & Disclosures section with all tiles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ThemeBloc>(
            create: (_) => di.sl<ThemeBloc>(),
            child: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final legalHeader = find.byKey(const ValueKey('profile_legal_section_header'));
      await tester.scrollUntilVisible(
        legalHeader,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(legalHeader, findsOneWidget);
      expect(find.byKey(const ValueKey('profile_privacy_policy_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_terms_of_use_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_financial_disclaimer_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_ad_disclosure_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_licenses_tile')), findsOneWidget);
    });
  });

  group('FeroCalc Phase 5.1.0.1: Data Deletion & Privacy Architecture Tests', () {
    testWidgets('6. NotificationSettingsScreen renders Data Privacy & Deletion section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: NotificationSettingsScreen()),
      );
      await tester.pumpAndSettle();

      final privacySection = find.byKey(const ValueKey('notification_data_privacy_section'));
      await tester.scrollUntilVisible(
        privacySection,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(privacySection, findsOneWidget);
      expect(find.text('Data Privacy & Deletion'), findsOneWidget);
      expect(find.byKey(const ValueKey('delete_remote_notification_data_button')), findsOneWidget);
      expect(find.textContaining('ferocalc.app@gmail.com'), findsOneWidget);
    });

    test('7. Data deletion mechanism revokes remote token and preserves local calculations and goals', () async {
      final historyRepo = di.sl<CalculationHistoryRepository>();
      final goalRepo = di.sl<GoalRepository>();
      final profileRepo = di.sl<FinancialProfileRepository>();
      final notifService = di.sl<NotificationService>();

      // 1. Seed calculation history
      await historyRepo.saveEntry(CalculationHistoryEntry(
        id: 'calc_audit_preserve_1',
        calculatorId: 'fd_calculator',
        calculatorName: 'Fixed Deposit Calculator',
        inputs: {'principal': '100000', 'rate': '7.5', 'tenure': '3'},
        results: {'maturity': '124972'},
        primaryResultLabel: 'Maturity Amount',
        primaryResultValue: '₹1,24,972',
        timestamp: DateTime.now(),
      ),);

      // 2. Seed financial goal
      await goalRepo.saveGoal(FinancialGoal(
        id: 'goal_audit_preserve_1',
        name: 'Preserved Emergency Fund',
        category: GoalCategory.emergencyFund,
        targetAmount: 200000,
        currentSavings: 50000,
        targetMonths: 12,
        targetDate: DateTime.now().add(const Duration(days: 365)),
        monthlyContribution: 10000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),);

      // 3. Seed financial profile
      await profileRepo.saveProfile(const FinancialProfile(
        monthlyIncome: 80000,
        essentialExpenses: 30000,
        discretionaryExpenses: 10000,
      ),);

      // 4. Set device token
      await notifService.updateDeviceToken('test_push_device_token_xyz');
      expect(await notifService.getToken(), 'test_push_device_token_xyz');

      // 5. Execute remote registration deletion
      final deletionSuccess = await notifService.deleteRemoteRegistration();
      expect(deletionSuccess, true);

      // 6. Verify token is revoked and local preferences disabled
      expect(await notifService.getToken(), null);

      // 7. Verify NO accidental deletion of goals, calculations, or financial profile
      final historyList = await historyRepo.getHistory();
      expect(
        historyList.any((e) => e.id == 'calc_audit_preserve_1'),
        true,
        reason: 'Calculation history must NOT be deleted by remote notification deletion',
      );

      final goalsList = await goalRepo.getGoals();
      expect(
        goalsList.any((g) => g.id == 'goal_audit_preserve_1'),
        true,
        reason: 'Financial goals must NOT be deleted by remote notification deletion',
      );

      final profile = await profileRepo.getProfile();
      expect(
        profile.monthlyIncome,
        80000,
        reason: 'Financial profile metrics must NOT be deleted by remote notification deletion',
      );
    });
  });

  group('FeroCalc Phase 5.1.0.1: Android Backup & Platform Security Tests', () {
    test('8. Android manifest specifies safe backup, cleartext blocking, and least permissions', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), true, reason: 'AndroidManifest.xml must exist');

      final content = manifestFile.readAsStringSync();

      // Least-privilege permissions check
      expect(content.contains('android.permission.INTERNET'), true);
      expect(content.contains('android.permission.READ_CONTACTS'), false);
      expect(content.contains('android.permission.WRITE_CONTACTS'), false);
      expect(content.contains('android.permission.ACCESS_FINE_LOCATION'), false);
      expect(content.contains('android.permission.ACCESS_COARSE_LOCATION'), false);
      expect(content.contains('android.permission.NEARBY_WIFI_DEVICES'), false);

      // Backup & cleartext security flags
      expect(content.contains('android:allowBackup="true"'), true);
      expect(content.contains('android:dataExtractionRules="@xml/data_extraction_rules"'), true);
      expect(content.contains('android:fullBackupContent="@xml/backup_rules"'), true);
      expect(content.contains('android:usesCleartextTraffic="false"'), true);
    });

    test('9. Android backup rules explicitly exclude FlutterSharedPreferences.xml to isolate sensitive data', () {
      final extractionRulesFile = File('android/app/src/main/res/xml/data_extraction_rules.xml');
      expect(extractionRulesFile.existsSync(), true);
      final extractionContent = extractionRulesFile.readAsStringSync();
      expect(extractionContent.contains('<data-extraction-rules>'), true);
      expect(extractionContent.contains('<cloud-backup>'), true);
      expect(extractionContent.contains('<device-transfer>'), true);
      expect(extractionContent.contains('FlutterSharedPreferences.xml'), true);

      final backupRulesFile = File('android/app/src/main/res/xml/backup_rules.xml');
      expect(backupRulesFile.existsSync(), true);
      final backupContent = backupRulesFile.readAsStringSync();
      expect(backupContent.contains('<full-backup-content>'), true);
      expect(backupContent.contains('FlutterSharedPreferences.xml'), true);
    });

    test('10. Home screen contains explicit ADVERTISEMENT badge for Google AdMob attribution', () {
      final homeScreenFile = File('lib/features/home/presentation/screens/home_screen.dart');
      expect(homeScreenFile.existsSync(), true);
      final content = homeScreenFile.readAsStringSync();

      expect(content.contains('ADVERTISEMENT'), true);
      expect(content.contains('Sponsored advertisement banner'), true);
    });
  });

  group('FeroCalc Phase 5.1.0.1: Documentation & Regulatory Wording Audit Tests', () {
    test('11. Data safety draft explicitly documents user product interactions, diagnostics, and deletion', () {
      final dataSafetyFile = File('docs/release/google_play_data_safety_draft.md');
      expect(dataSafetyFile.existsSync(), true);
      final content = dataSafetyFile.readAsStringSync();

      expect(content.contains('App Activity & User Product Interactions'), true);
      expect(content.contains('App Interactions'), true);
      expect(content.contains('Diagnostics & Performance'), true);
      expect(content.contains('play-services-ads:25.4.0'), true);
      expect(content.contains('Do you provide a way for users to request that their data be deleted?'), true);
      expect(content.contains('YES'), true);
      expect(content.contains('DELETE /api/notifications/device-token'), true);
    });

    test('12. Trader status guidance states 1 February 2027 deadline and commercial evaluation', () {
      final checklistFile = File('docs/release/google_play_app_content_checklist.md');
      expect(checklistFile.existsSync(), true);
      final checklistContent = checklistFile.readAsStringSync();
      expect(checklistContent.contains('1 February 2027'), true);

      final blockerFile = File('docs/release/production_blocker_register.md');
      expect(blockerFile.existsSync(), true);
      final blockerContent = blockerFile.readAsStringSync();
      expect(blockerContent.contains('1 February 2027'), true);
      expect(blockerContent.contains('ACT-01'), true);

      final dataSafetyFile = File('docs/release/google_play_data_safety_draft.md');
      final dataSafetyContent = dataSafetyFile.readAsStringSync();
      expect(dataSafetyContent.contains('1 February 2027'), true);
      expect(dataSafetyContent.contains('ad-monetization'), true);
    });
  });
}
