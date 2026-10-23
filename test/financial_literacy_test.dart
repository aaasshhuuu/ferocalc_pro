import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/data/financial_literacy_data.dart';
import 'package:fincalc_pro/core/services/financial_literacy_translation_service.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/compare/presentation/screens/compare_screen.dart';
import 'package:fincalc_pro/features/insights/presentation/screens/financial_literacy_detail_screen.dart';
import 'package:fincalc_pro/features/insights/presentation/screens/financial_literacy_hub_screen.dart';
import 'package:fincalc_pro/features/insights/presentation/screens/financial_management_detail_screen.dart';
import 'package:fincalc_pro/features/insights/presentation/screens/insights_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({String initialLocation = '/insights'}) {
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

  group('Financial Literacy Data & Model Tests', () {
    test('12. Every initial topic has valid unique ID and non-empty structured fields', () {
      final topics = FinancialLiteracyData.getAllTopics();
      expect(topics.length, greaterThanOrEqualTo(21));

      final idSet = <String>{};
      for (final topic in topics) {
        expect(topic.id.isNotEmpty, isTrue);
        expect(idSet.contains(topic.id), isFalse, reason: 'Duplicate topic id: ${topic.id}');
        idSet.add(topic.id);

        expect(topic.title.isNotEmpty, isTrue);
        expect(topic.shortDescription.isNotEmpty, isTrue);
        expect(topic.category.isNotEmpty, isTrue);
        expect(topic.whatIsIt.isNotEmpty, isTrue);
        expect(topic.whyItMatters.isNotEmpty, isTrue);
        expect(topic.howItWorks.isNotEmpty, isTrue);
      }
    });

    test('QA Clarification: Exact 24 visible topics include Rule of 72, Rule of 114, 70/20/10 and Emergency Fund', () {
      final topics = FinancialLiteracyData.getAllTopics();
      expect(topics.length, equals(24));

      final topicIds = topics.map((t) => t.id).toList();

      // Explicitly verifies presence of Rule of 72, Rule of 114, 70/20/10, and Emergency Fund
      expect(topicIds, contains('rule-of-72'));
      expect(topicIds, contains('rule-of-114'));
      expect(topicIds, contains('70-20-10'));
      expect(topicIds, contains('emergency-fund'));

      // Verifies that the topics reused from Financial Management have non-null financialManagementTopicId
      final ruleOf72 = FinancialLiteracyData.getTopicById('rule-of-72')!;
      expect(ruleOf72.financialManagementTopicId, equals('rule-of-72'));
      expect(ruleOf72.title, equals('Rule of 72'));

      final ruleOf114 = FinancialLiteracyData.getTopicById('rule-of-114')!;
      expect(ruleOf114.financialManagementTopicId, equals('rule-of-114'));
      expect(ruleOf114.title, equals('Rule of 114'));

      final rule702010 = FinancialLiteracyData.getTopicById('70-20-10')!;
      expect(rule702010.financialManagementTopicId, equals('70-20-10'));
      expect(rule702010.title, equals('70/20/10 Rule'));

      final emergencyFund = FinancialLiteracyData.getTopicById('emergency-fund')!;
      expect(emergencyFund.financialManagementTopicId, equals('emergency-fund'));
      expect(emergencyFund.title, equals('Emergency Fund'));
    });

    test('QA Clarification: All 10 Financial Management topics are accessible via the Hub adapter/service', () {
      final service = di.sl<FinancialLiteracyTranslationService>();
      const allManagementIds = [
        'rule-of-72',
        'emergency-fund',
        'start-sip-early',
        'tax-saving',
        'ppf-returns',
        'nps-benefits',
        'fd-taxation',
        'sukanya-samriddhi',
        'rule-of-114',
        '70-20-10',
      ];

      for (final id in allManagementIds) {
        final translatedTopic = service.getTranslatedTopicById(id);
        expect(translatedTopic, isNotNull, reason: 'Topic $id should be accessible through Hub service');
        expect(translatedTopic!.title.isNotEmpty, isTrue);
      }
    });

    test('11. Important topics use isImportant metadata without hard-coding', () {
      final importantTopics = FinancialLiteracyData.getImportantTopics();
      expect(importantTopics.isNotEmpty, isTrue);
      for (final topic in importantTopics) {
        expect(topic.isImportant, isTrue);
      }

      final nonImportant = FinancialLiteracyData.getAllTopics().where((t) => !t.isImportant);
      expect(nonImportant.isNotEmpty, isTrue);
    });

    test('6. Search works matching title, description, category, and keywords (case-insensitive)', () {
      // By title
      final byTitle = FinancialLiteracyData.searchTopics(query: 'compound interest');
      expect(byTitle.any((t) => t.id == 'compound-interest-basics'), isTrue);

      // By keyword
      final byKeyword = FinancialLiteracyData.searchTopics(query: 'eighth wonder');
      expect(byKeyword.any((t) => t.id == 'compound-interest-basics'), isTrue);

      // By description
      final byDesc = FinancialLiteracyData.searchTopics(query: 'catastrophic financial risk');
      expect(byDesc.any((t) => t.id == 'insurance-basics'), isTrue);

      // Trimming & Case-insensitivity
      final upper = FinancialLiteracyData.searchTopics(query: '  INFLATION  ');
      expect(upper.any((t) => t.id == 'inflation-basics'), isTrue);
    });

    test('7. Category filter returns only topics in that category', () {
      final bankingTopics = FinancialLiteracyData.getTopicsByCategory(FinancialLiteracyCategories.banking);
      expect(bankingTopics.isNotEmpty, isTrue);
      for (final t in bankingTopics) {
        expect(t.category, equals(FinancialLiteracyCategories.banking));
      }

      final allTopics = FinancialLiteracyData.getTopicsByCategory(FinancialLiteracyCategories.all);
      expect(allTopics.length, equals(FinancialLiteracyData.getAllTopics().length));
    });

    test('8. Search + category filter work together correctly', () {
      // Search 'deposit' in Banking
      final bankingDeposits = FinancialLiteracyData.searchTopics(
        query: 'deposit',
        category: FinancialLiteracyCategories.banking,
      );
      expect(bankingDeposits.isNotEmpty, isTrue);
      for (final t in bankingDeposits) {
        expect(t.category, equals(FinancialLiteracyCategories.banking));
      }

      // Search 'deposit' in Insurance (should be empty)
      final insuranceDeposits = FinancialLiteracyData.searchTopics(
        query: 'deposit',
        category: FinancialLiteracyCategories.insurance,
      );
      expect(insuranceDeposits, isEmpty);
    });

    test('9 & 10. Empty search restores topics and no-result returns empty list', () {
      final restored = FinancialLiteracyData.searchTopics(query: '');
      expect(restored.length, equals(FinancialLiteracyData.getAllTopics().length));

      final noResults = FinancialLiteracyData.searchTopics(query: 'completely-nonexistent-search-term-xyz');
      expect(noResults, isEmpty);
    });
  });

  group('Financial Literacy Hub & Insights Widget Tests', () {
    testWidgets('1, 2, 3. Interest Rate Tracker removed from Insights, Financial Literacy entry appears and opens route', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 1. Verify Interest Rate Tracker is removed
      expect(find.text('Interest Rate Tracker'), findsNothing);
      expect(find.text('RBI Repo Rate'), findsNothing);
      expect(find.text('SBI Base Rate'), findsNothing);

      // 2. Verify Financial Literacy entry card appears
      final entryCardFinder = find.byKey(const ValueKey('financial_literacy_entry_card'));
      expect(entryCardFinder, findsOneWidget);
      expect(find.text('Explore Financial Literacy Hub'), findsOneWidget);

      // 3. Tap card opens /financial-literacy route
      await tester.ensureVisible(entryCardFinder);
      await tester.tap(entryCardFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 4. Hub loads
      expect(find.byType(FinancialLiteracyHubScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('literacy_search_field')), findsOneWidget);
    });

    testWidgets('5. Expected categories appear as filter chips', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/financial-literacy'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final chipsList = find.byKey(const ValueKey('category_chips_list'));
      expect(chipsList, findsOneWidget);

      for (final cat in FinancialLiteracyCategories.values) {
        final chipFinder = find.byKey(ValueKey('category_chip_$cat'));
        await tester.scrollUntilVisible(
          chipFinder,
          100.0,
          scrollable: find.descendant(
            of: chipsList,
            matching: find.byType(Scrollable),
          ),
        );
        expect(chipFinder, findsOneWidget);
      }
    });

    testWidgets('6, 7, 8, 9, 10. Search field, category selection, and clear filter button work interactively in Hub', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/financial-literacy'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Enter search query
      final searchField = find.byKey(const ValueKey('literacy_search_field'));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'Insurance');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Insurance & Protection Basics'), findsOneWidget);

      // Clear search
      final clearBtn = find.byKey(const ValueKey('literacy_search_clear_button'));
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Enter query with zero results
      await tester.enterText(searchField, 'NonExistentXYZWord123');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('No matching topics found'), findsOneWidget);
      final clearFilterBtn = find.byKey(const ValueKey('literacy_clear_filters_button'));
      expect(clearFilterBtn, findsOneWidget);
      await tester.tap(clearFilterBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Topics restored
      expect(find.text('No matching topics found'), findsNothing);
    });

    testWidgets('13 & 14. Topic cards are clickable and open correct detail page with structured sections', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/financial-literacy'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Find and tap Compound Interest card
      final cardFinder = find.byKey(const ValueKey('literacy_card_compound-interest-basics'));
      expect(cardFinder, findsOneWidget);
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verifies on detail page for Compound Interest
      expect(find.byType(FinancialLiteracyDetailScreen), findsOneWidget);
      expect(find.text('Compound Interest Basics'), findsWidgets);
      expect(find.text('What is it?'), findsOneWidget);
      expect(find.text('Why It Matters'), findsOneWidget);
      expect(find.text('How It Works'), findsOneWidget);
      expect(find.text('Formula / Rule Framework'), findsOneWidget);
      expect(find.text('Practical Applications'), findsOneWidget);
      expect(find.byKey(const ValueKey('related_calc_button_compound-interest-basics')), findsOneWidget);
    });

    testWidgets('15. Existing Financial Management navigation continues working unchanged', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final emergencyCardFinder = find.byKey(const ValueKey('financial_management_card_emergency-fund'));
      expect(emergencyCardFinder, findsOneWidget);
      await tester.ensureVisible(emergencyCardFinder);
      await tester.tap(emergencyCardFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FinancialManagementDetailScreen), findsOneWidget);
      expect(find.text('Emergency Fund'), findsWidgets);

      // Back to insights
      final handledBack = await tester.binding.handlePopRoute();
      expect(handledBack, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);
    });

    testWidgets('16. Existing calculator navigation still works', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final emiFinder = find.widgetWithText(InkWell, 'EMI Calculator');
      expect(emiFinder, findsOneWidget);
      await tester.ensureVisible(emiFinder);
      await tester.tap(emiFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('EMI Calculator'), findsWidgets);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);
    });

    testWidgets('17. Existing bank comparison navigation still works', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/compare'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CompareScreen), findsOneWidget);
    });

    testWidgets('18. Android Back navigation works from Topic Detail -> Hub -> Insights', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Start at Insights
      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);

      // Open Hub
      final entryCard = find.byKey(const ValueKey('financial_literacy_entry_card'));
      await tester.ensureVisible(entryCard);
      await tester.tap(entryCard);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FinancialLiteracyHubScreen), findsOneWidget);

      // Open a Topic Detail
      final topicCard = find.byKey(const ValueKey('literacy_card_saving-basics'));
      expect(topicCard, findsOneWidget);
      await tester.ensureVisible(topicCard);
      await tester.tap(topicCard);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FinancialLiteracyDetailScreen), findsOneWidget);

      // Back 1: Returns to Hub
      final back1 = await tester.binding.handlePopRoute();
      expect(back1, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FinancialLiteracyHubScreen), findsOneWidget);

      // Back 2: Returns to Insights
      final back2 = await tester.binding.handlePopRoute();
      expect(back2, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);
    });

    testWidgets('19. 360x640 layout on Hub and Detail screens produces zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Test Hub on 360x640
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const Scaffold(body: FinancialLiteracyHubScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Financial Literacy'), findsWidgets);

      // Test Detail screen on 360x640
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const FinancialLiteracyDetailScreen(topicId: 'budgeting-basics'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Budgeting Fundamentals'), findsWidgets);
    });
  });
}
