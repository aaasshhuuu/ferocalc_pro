import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/data/financial_literacy_data.dart';
import 'package:fincalc_pro/core/models/financial_literacy_language.dart';
import 'package:fincalc_pro/core/models/financial_literacy_topic.dart';
import 'package:fincalc_pro/core/services/financial_literacy_translation_service.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/insights/presentation/screens/financial_literacy_detail_screen.dart';
import 'package:fincalc_pro/features/insights/presentation/screens/financial_literacy_hub_screen.dart';
import 'package:fincalc_pro/features/insights/presentation/screens/financial_management_detail_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({String initialLocation = '/financial-literacy'}) {
  appRouter.go(initialLocation);
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()),
      BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
    ],
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  setUp(() {
    FinancialLiteracyTranslationService.resetForTesting(
      initialLanguage: FinancialLiteracyLanguage.english,
    );
  });

  group('Financial Literacy Translator Unit & Service Tests', () {
    test('1. English is default on clean startup', () {
      final service = FinancialLiteracyTranslationService(preferences: null);
      expect(service.currentLanguage, equals(FinancialLiteracyLanguage.english));
      expect(service.currentLanguage.code, equals('en'));
    });

    test('5, 6, 7. Persistence, App Restart restoration, and Invalid code fallback', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // 5. Selected language persists
      final service1 = FinancialLiteracyTranslationService(preferences: prefs);
      await service1.setLanguage(FinancialLiteracyLanguage.hindi);
      expect(prefs.getString(FinancialLiteracyTranslationService.languagePreferenceKey), equals('hi'));

      // 6. App restart restores persisted language
      final service2 = FinancialLiteracyTranslationService(preferences: prefs);
      expect(service2.currentLanguage, equals(FinancialLiteracyLanguage.hindi));

      // 7. Invalid stored language falls back safely to English
      await prefs.setString(FinancialLiteracyTranslationService.languagePreferenceKey, 'corrupt_xyz_99');
      final service3 = FinancialLiteracyTranslationService(preferences: prefs);
      expect(service3.currentLanguage, equals(FinancialLiteracyLanguage.english));
    });

    test('9 & 10. Hindi translation translates text while keeping mathematical formulas/values intact', () {
      final service = FinancialLiteracyTranslationService(preferences: null);
      final siTopic = FinancialLiteracyData.getTopicById('simple-interest-basics')!;

      final hiTopic = service.getTranslatedTopic(siTopic, FinancialLiteracyLanguage.hindi);
      expect(hiTopic.language, equals(FinancialLiteracyLanguage.hindi));
      expect(hiTopic.isTranslated, isTrue);

      // Translated text
      expect(hiTopic.title, equals('साधारण ब्याज (Simple Interest)'));
      expect(hiTopic.whatIsIt.contains('साधारण ब्याज वह विधि है'), isTrue);

      // Mathematical formulas, numbers, and percentages MUST remain unchanged
      expect(hiTopic.formulaOrFramework!.contains('SI = (P × R × T) / 100'), isTrue);
      expect(hiTopic.formulaOrFramework!.contains('A = P + SI = P × (1 + (R × T / 100))'), isTrue);
      expect(hiTopic.example!.contains('₹1,00,000'), isTrue);
      expect(hiTopic.example!.contains('8% p.a.'), isTrue);
      expect(hiTopic.example!.contains('₹24,000'), isTrue);
    });

    test('9 & 10. Gujarati translation translates text while keeping mathematical formulas/values intact', () {
      final service = FinancialLiteracyTranslationService(preferences: null);
      final ciTopic = FinancialLiteracyData.getTopicById('compound-interest-basics')!;

      final guTopic = service.getTranslatedTopic(ciTopic, FinancialLiteracyLanguage.gujarati);
      expect(guTopic.language, equals(FinancialLiteracyLanguage.gujarati));
      expect(guTopic.isTranslated, isTrue);

      // Translated text
      expect(guTopic.title, equals('ચક્રવૃદ્ધિ વ્યાજ (Compound Interest)'));
      expect(guTopic.whatIsIt.contains('ચક્રવૃદ્ધિ વ્યાજ એ એવી પ્રક્રિયા છે'), isTrue);

      // Mathematical formula remains unchanged
      expect(guTopic.formulaOrFramework!.contains('A = P × (1 + R / (100 × n))^(n × T)'), isTrue);
      expect(guTopic.formulaOrFramework!.contains('CI = A - P'), isTrue);
      expect(guTopic.example!.contains('₹1,00,000'), isTrue);
      expect(guTopic.example!.contains('10%'), isTrue);
      expect(guTopic.example!.contains('₹6,72,750'), isTrue);
    });

    test('11. Missing translation falls back safely and deterministically to English', () {
      final service = FinancialLiteracyTranslationService(preferences: null);

      // Construct a mock custom topic with no translation in the dictionary
      const mockTopic = FinancialLiteracyTopic(
        id: 'untranslated-mock-topic-123',
        title: 'Untranslated Test Topic Title',
        shortDescription: 'Untranslated description for test fallback',
        category: 'Personal Finance',
        whatIsIt: 'English canonical what is it text.',
        whyItMatters: 'English canonical why it matters text.',
        howItWorks: 'English canonical how it works text.',
        formulaOrFramework: 'X = Y + Z',
        example: 'Canonical Example ₹500',
        practicalUses: ['Canonical practical use 1'],
        importantPoints: ['Canonical important point 1'],
        limitations: ['Canonical limitation 1'],
        disclaimer: 'Canonical disclaimer.',
        relatedCalculatorRoute: '/calculator/emi',
        relatedCalculatorLabel: 'Open Canonical Calculator',
      );

      final resolvedHi = service.getTranslatedTopic(mockTopic, FinancialLiteracyLanguage.hindi);
      expect(resolvedHi.title, equals('Untranslated Test Topic Title'));
      expect(resolvedHi.shortDescription, equals('Untranslated description for test fallback'));
      expect(resolvedHi.whatIsIt, equals('English canonical what is it text.'));
      expect(resolvedHi.formulaOrFramework, equals('X = Y + Z'));
      expect(resolvedHi.example, equals('Canonical Example ₹500'));
      expect(resolvedHi.practicalUses, equals(['Canonical practical use 1']));
      expect(resolvedHi.disclaimer, equals('Canonical disclaimer.'));
      expect(resolvedHi.relatedCalculatorLabel, equals('Open Canonical Calculator'));
    });

    test('12. Financial Management referenced content remains consistent in translation', () {
      final service = FinancialLiteracyTranslationService(preferences: null);

      // Rule of 72
      final r72 = service.getTranslatedTopicById('rule-of-72', FinancialLiteracyLanguage.hindi);
      expect(r72, isNotNull);
      expect(r72!.title, equals('72 का नियम (Rule of 72)'));
      expect(r72.formulaOrFramework!.contains('72 / R'), isTrue);

      // Rule of 114 in Gujarati
      final r114 = service.getTranslatedTopicById('rule-of-114', FinancialLiteracyLanguage.gujarati);
      expect(r114, isNotNull);
      expect(r114!.title, equals('114 નો નિયમ (Rule of 114)'));
      expect(r114.formulaOrFramework!.contains('114 / R'), isTrue);

      // 70/20/10 in Hindi
      final b702010 = service.getTranslatedTopicById('70-20-10', FinancialLiteracyLanguage.hindi);
      expect(b702010, isNotNull);
      expect(b702010!.title, equals('70/20/10 का बजट नियम'));
      expect(b702010.formulaOrFramework!.contains('70%'), isTrue);
      expect(b702010.formulaOrFramework!.contains('20%'), isTrue);
      expect(b702010.formulaOrFramework!.contains('10%'), isTrue);
    });

    test('13, 14, 15. Multilingual Search & Category Filtering work across languages', () {
      final service = FinancialLiteracyTranslationService(preferences: null);

      // 13. Search in English while language is English
      final enSearch = service.searchTopics(query: 'Compound Interest', language: FinancialLiteracyLanguage.english);
      expect(enSearch.any((t) => t.id == 'compound-interest-basics'), isTrue);

      // Search in Hindi while language is Hindi
      final hiSearch = service.searchTopics(query: 'चक्रवृद्धि', language: FinancialLiteracyLanguage.hindi);
      expect(hiSearch.any((t) => t.id == 'compound-interest-basics'), isTrue);

      // Search in Gujarati while language is Gujarati
      final guSearch = service.searchTopics(query: 'ચક્રવૃદ્ધિ', language: FinancialLiteracyLanguage.gujarati);
      expect(guSearch.any((t) => t.id == 'compound-interest-basics'), isTrue);

      // 14. Category filter remains intact
      final savingTopics = service.searchTopics(
        query: '',
        category: 'Saving',
        language: FinancialLiteracyLanguage.hindi,
      );
      expect(savingTopics.isNotEmpty, isTrue);
      for (final t in savingTopics) {
        expect(t.category, equals('Saving'));
      }

      // 15. Combined search + category filter
      final combined = service.searchTopics(
        query: 'બચત', // partial Gujarati
        category: 'Saving',
        language: FinancialLiteracyLanguage.gujarati,
      );
      expect(combined.isNotEmpty, isTrue);
    });
  });

  group('Financial Literacy Translator Widget & UI Tests', () {
    testWidgets('2, 3, 4. Language selector appears, allows selecting Hindi and Gujarati', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/financial-literacy'));
      await tester.pumpAndSettle();

      // 2. Language selector button appears in AppBar
      final selectorButton = find.byKey(const ValueKey('financial_literacy_language_selector'));
      expect(selectorButton, findsOneWidget);

      // Current badge shows English
      expect(find.byKey(const ValueKey('selected_language_badge')), findsOneWidget);
      expect(find.text('English'), findsWidgets);

      // Tap selector to open sheet
      await tester.tap(selectorButton);
      await tester.pumpAndSettle();

      // Options appear
      expect(find.byKey(const ValueKey('language_option_en')), findsOneWidget);
      expect(find.byKey(const ValueKey('language_option_hi')), findsOneWidget);
      expect(find.byKey(const ValueKey('language_option_gu')), findsOneWidget);

      // 3. Select Hindi
      await tester.tap(find.byKey(const ValueKey('language_option_hi')));
      await tester.pumpAndSettle();

      expect(FinancialLiteracyTranslationService.instance.currentLanguage, equals(FinancialLiteracyLanguage.hindi));
      expect(find.text('हिन्दी'), findsWidgets);

      // 4. Select Gujarati
      await tester.tap(find.byKey(const ValueKey('financial_literacy_language_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language_option_gu')));
      await tester.pumpAndSettle();

      expect(FinancialLiteracyTranslationService.instance.currentLanguage, equals(FinancialLiteracyLanguage.gujarati));
      expect(find.text('ગુજરાતી'), findsWidgets);
    });

    testWidgets('8 & 9. Language switch preserves current topic and dynamically updates content without reload', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Navigate to Simple Interest detail in English
      FinancialLiteracyTranslationService.resetForTesting(initialLanguage: FinancialLiteracyLanguage.english);
      await tester.pumpWidget(_buildTestApp(initialLocation: '/financial-literacy/simple-interest-basics'));
      await tester.pumpAndSettle();

      // Verified in English
      expect(find.byType(FinancialLiteracyDetailScreen), findsOneWidget);
      expect(find.text('Simple Interest Basics'), findsWidgets);
      expect(find.text('What is it?'), findsOneWidget);

      // Tap language selector
      final selectorButton = find.byKey(const ValueKey('financial_literacy_language_selector'));
      expect(selectorButton, findsOneWidget);
      await tester.tap(selectorButton);
      await tester.pumpAndSettle();

      // Switch to Hindi
      await tester.tap(find.byKey(const ValueKey('language_option_hi')));
      await tester.pumpAndSettle();

      // 8. Remains on current topic
      expect(find.byType(FinancialLiteracyDetailScreen), findsOneWidget);

      // 9. Topic content and section headers updated to Hindi
      expect(find.text('साधारण ब्याज (Simple Interest)'), findsWidgets);
      expect(find.text('यह क्या है?'), findsOneWidget);
      expect(find.text('यह क्यों महत्वपूर्ण है?'), findsOneWidget);
      expect(find.text('यह कैसे काम करता है?'), findsOneWidget);

      // Switch to Gujarati
      await tester.tap(selectorButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language_option_gu')));
      await tester.pumpAndSettle();

      // Remains on current topic and updates to Gujarati
      expect(find.byType(FinancialLiteracyDetailScreen), findsOneWidget);
      expect(find.text('સાદું વ્યાજ (Simple Interest)'), findsWidgets);
      expect(find.text('આ શું છે?'), findsOneWidget);
      expect(find.text('આ શા માટે મહત્વપૂર્ણ છે?'), findsOneWidget);
    });

    testWidgets('16. 360x640 layout in Hindi and Gujarati produces zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Test Hindi Hub & Detail Screen on 360x640
      FinancialLiteracyTranslationService.resetForTesting(initialLanguage: FinancialLiteracyLanguage.hindi);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const Scaffold(body: FinancialLiteracyHubScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('वित्तीय साक्षरता'), findsWidgets);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const FinancialLiteracyDetailScreen(topicId: 'budgeting-basics'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('बजट के मूलभूत सिद्धांत'), findsWidgets);

      // Test Gujarati Hub & Detail Screen on 360x640
      FinancialLiteracyTranslationService.resetForTesting(initialLanguage: FinancialLiteracyLanguage.gujarati);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const Scaffold(body: FinancialLiteracyHubScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('નાણાકીય સાક્ષરતા'), findsWidgets);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const FinancialLiteracyDetailScreen(topicId: 'compound-interest-basics'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ચક્રવૃદ્ધિ વ્યાજ (Compound Interest)'), findsWidgets);
    });

    testWidgets('17 & 18. Existing Financial Literacy and Financial Management navigation still works', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 17. Existing Financial Literacy Hub to Detail navigation
      await tester.pumpWidget(_buildTestApp(initialLocation: '/financial-literacy'));
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const ValueKey('literacy_card_budgeting-basics'));
      expect(cardFinder, findsOneWidget);
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(FinancialLiteracyDetailScreen), findsOneWidget);

      // Back returns to Hub
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(FinancialLiteracyHubScreen), findsOneWidget);

      // 18. Existing Financial Management navigation remains intact
      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights/financial-management/rule-of-114'));
      await tester.pumpAndSettle();
      expect(find.byType(FinancialManagementDetailScreen), findsOneWidget);
      expect(find.text('Rule of 114'), findsWidgets);
    });
  });
}
