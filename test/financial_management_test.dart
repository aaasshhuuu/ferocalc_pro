import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/data/financial_management_data.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
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

  group('FinancialManagementData Domain & Model Tests', () {
    test('Registry contains all 10 financial management topics (8 original + 2 new)', () {
      final topics = FinancialManagementData.getAllTopics();
      expect(topics.length, equals(10));

      final expectedIds = [
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

      for (final id in expectedIds) {
        final topic = FinancialManagementData.getTopicById(id);
        expect(topic, isNotNull, reason: 'Topic $id must exist in registry');
        expect(topic!.id, equals(id));
        expect(topic.title.isNotEmpty, isTrue);
        expect(topic.shortDescription.isNotEmpty, isTrue);
        expect(topic.whatIsIt.isNotEmpty, isTrue);
        expect(topic.whyItMatters.isNotEmpty, isTrue);
        expect(topic.howItWorks.isNotEmpty, isTrue);
        expect(topic.practicalUses.isNotEmpty, isTrue);
        expect(topic.importantPoints.isNotEmpty, isTrue);
        expect(topic.disclaimer, isNotNull);
      }
    });

    test('getTopicById safely handles case insensitivity and underscore variations', () {
      expect(FinancialManagementData.getTopicById('rule_of_72'), isNotNull);
      expect(FinancialManagementData.getTopicById('RULE-OF-72'), isNotNull);
      expect(FinancialManagementData.getTopicById('emergency_fund'), isNotNull);
      expect(FinancialManagementData.getTopicById('START_SIP_EARLY'), isNotNull);
    });

    test('getTopicById returns null safely for unknown topic ID', () {
      expect(FinancialManagementData.getTopicById('non-existent-topic'), isNull);
      expect(FinancialManagementData.getTopicById(''), isNull);
    });

    test('Key topics have isKeyTopic set to true for visual emphasis', () {
      final rule72 = FinancialManagementData.getTopicById('rule-of-72');
      final emergencyFund = FinancialManagementData.getTopicById('emergency-fund');
      final startSip = FinancialManagementData.getTopicById('start-sip-early');
      final rule114 = FinancialManagementData.getTopicById('rule-of-114');
      final rule702010 = FinancialManagementData.getTopicById('70-20-10');

      expect(rule72?.isKeyTopic, isTrue);
      expect(emergencyFund?.isKeyTopic, isTrue);
      expect(startSip?.isKeyTopic, isTrue);
      expect(rule114?.isKeyTopic, isTrue);
      expect(rule702010?.isKeyTopic, isTrue);
    });

    test('Rule of 114 exists in registry with proper mathematical approximation content', () {
      final topic = FinancialManagementData.getTopicById('rule-of-114');
      expect(topic, isNotNull);
      expect(topic!.title, equals('Rule of 114'));
      expect(topic.formulaOrRule, contains('114 / Annual Return Rate'));
      expect(topic.example, contains('14.25 years'));
      expect(topic.importantPoints.any((p) => p.contains('Mental shortcut')), isTrue);
      expect(topic.disclaimer, contains('approximation'));
      expect(topic.relatedCalculatorRoute, equals('/calculator/compound_interest'));
    });

    test('70/20/10 exists in registry with proper budgeting framework content', () {
      final topic = FinancialManagementData.getTopicById('70-20-10');
      expect(topic, isNotNull);
      expect(topic!.title, equals('70/20/10 Rule'));
      expect(topic.formulaOrRule, contains('70% Living Expenses'));
      expect(topic.example, contains('50,000'));
      expect(topic.importantPoints.any((p) => p.contains('Guideline, not a universal mandate')), isTrue);
      expect(topic.disclaimer, contains('educational budgeting guideline'));
      expect(topic.relatedCalculatorRoute, equals('/calculator/sip'));
    });
  });

  group('InsightsScreen Financial Management Section Widget Tests', () {
    testWidgets('1. Section title is renamed to "Financial Management"', (tester) async {
      tester.view.physicalSize = const Size(1080, 2240);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Title must be Financial Management
      expect(find.text('Financial Management'), findsOneWidget);
    });

    testWidgets('2. Every currently existing Financial Management topic is present', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400); // desktop width to render all grid items
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Rule of 72'), findsOneWidget);
      expect(find.text('Emergency Fund'), findsOneWidget);
      expect(find.text('Start SIP Early'), findsOneWidget);
      expect(find.text('Tax Saving'), findsOneWidget);
      expect(find.text('PPF Returns'), findsOneWidget);
      expect(find.text('NPS Benefits'), findsOneWidget);
      expect(find.text('FD Taxation'), findsOneWidget);
      expect(find.text('Sukanya Samriddhi'), findsWidgets);
      expect(find.text('Rule of 114'), findsOneWidget);
      expect(find.text('70/20/10 Rule'), findsOneWidget);
    });

    testWidgets('3 & 4. Every topic is tappable and passes correct topic ID to detail page', (tester) async {
      tester.view.physicalSize = const Size(1080, 2240);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap Emergency Fund card
      final emergencyCardFinder = find.byKey(const ValueKey('financial_management_card_emergency-fund'));
      expect(emergencyCardFinder, findsOneWidget);
      await tester.ensureVisible(emergencyCardFinder);
      await tester.tap(emergencyCardFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verifies on detail page for emergency fund
      expect(find.byType(FinancialManagementDetailScreen), findsOneWidget);
      expect(find.text('Emergency Fund'), findsWidgets);
      expect(find.textContaining('Emergency Fund Target'), findsOneWidget);

      // Back to insights
      final handledBack = await tester.binding.handlePopRoute();
      expect(handledBack, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);
    });

    testWidgets('5. Detail page displays comprehensive topic-specific content and calculator button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2240);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights/financial-management/rule-of-72'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FinancialManagementDetailScreen), findsOneWidget);
      expect(find.text('Rule of 72'), findsWidgets);
      expect(find.text('Key Principle'), findsOneWidget);
      expect(find.text('What is it?'), findsOneWidget);
      expect(find.text('Why It Matters'), findsOneWidget);
      expect(find.text('How It Works'), findsOneWidget);
      expect(find.text('Formula / Rule Framework'), findsOneWidget);
      expect(find.text('Practical Example'), findsOneWidget);
      expect(find.text('Practical Applications'), findsOneWidget);
      expect(find.text('Important Points & Limitations'), findsOneWidget);
      expect(find.byKey(const ValueKey('related_calc_button_rule-of-72')), findsOneWidget);
    });

    testWidgets('6. Unknown topic ID is handled safely without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2240);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights/financial-management/unknown-fake-id'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Topic Not Found'), findsWidgets);
      expect(find.text('Return to Insights'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Android Back navigation returns from topic detail to Insights', (tester) async {
      tester.view.physicalSize = const Size(1080, 2240);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Push topic detail
      appRouter.push('/insights/financial-management/tax-saving');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FinancialManagementDetailScreen), findsOneWidget);

      // Trigger Android Back
      final popped = await tester.binding.handlePopRoute();
      expect(popped, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Returned to InsightsScreen
      expect(find.byType(InsightsScreen), findsOneWidget);
    });

    testWidgets('8. 360x640 layout on both Insights and Detail screen produces zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Check Insights screen on 360x640
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const Scaffold(body: InsightsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Financial Management'), findsOneWidget);

      // Check Detail screen on 360x640
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const FinancialManagementDetailScreen(topicId: 'sukanya-samriddhi'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sukanya Samriddhi'), findsWidgets);
    });

    testWidgets('9 & 10. Existing Quick Calculators navigation remains intact and Interest Rate Tracker is removed', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify Quick Calculator SIP
      final sipFinder = find.widgetWithText(InkWell, 'SIP Calculator');
      expect(sipFinder, findsOneWidget);
      await tester.ensureVisible(sipFinder);
      await tester.tap(sipFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('SIP Calculator'), findsWidgets);

      // Pop back
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);

      // Verify Interest Rate Tracker is removed and Financial Literacy is present
      expect(find.text('Interest Rate Tracker'), findsNothing);
      expect(find.text('RBI Repo Rate'), findsNothing);
      expect(find.byKey(const ValueKey('financial_literacy_entry_card')), findsOneWidget);
    });

    testWidgets('11. Rule of 114 card is clickable, renders detail page with formula & CI calculator, and handles Android Back', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap Rule of 114 card
      final cardFinder = find.byKey(const ValueKey('financial_management_card_rule-of-114'));
      expect(cardFinder, findsOneWidget);
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verifies on detail page for Rule of 114
      expect(find.byType(FinancialManagementDetailScreen), findsOneWidget);
      expect(find.text('Rule of 114'), findsWidgets);
      expect(find.textContaining('114 / Annual Return Rate'), findsOneWidget);
      expect(find.textContaining('14.25 years'), findsOneWidget);
      expect(find.byKey(const ValueKey('related_calc_button_rule-of-114')), findsOneWidget);

      // Back to insights
      final handledBack = await tester.binding.handlePopRoute();
      expect(handledBack, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);
    });

    testWidgets('12. 70/20/10 Rule card is clickable, renders detail page with framework & SIP calculator, and handles Android Back', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(initialLocation: '/insights'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap 70/20/10 card
      final cardFinder = find.byKey(const ValueKey('financial_management_card_70-20-10'));
      expect(cardFinder, findsOneWidget);
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verifies on detail page for 70/20/10 Rule
      expect(find.byType(FinancialManagementDetailScreen), findsOneWidget);
      expect(find.text('70/20/10 Rule'), findsWidgets);
      expect(find.textContaining('Take-Home Monthly Income (100%)'), findsOneWidget);
      expect(find.textContaining('70% Living Expenses'), findsWidgets);
      expect(find.textContaining('50,000'), findsOneWidget);
      expect(find.byKey(const ValueKey('related_calc_button_70-20-10')), findsOneWidget);

      // Back to insights
      final handledBack = await tester.binding.handlePopRoute();
      expect(handledBack, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(InsightsScreen), findsOneWidget);
    });

    testWidgets('13. 360x640 layout on both new detail screens produces zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Test Rule of 114 on 360x640
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const FinancialManagementDetailScreen(topicId: 'rule-of-114'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Rule of 114'), findsWidgets);

      // Test 70/20/10 on 360x640
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const FinancialManagementDetailScreen(topicId: '70-20-10'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('70/20/10 Rule'), findsWidgets);
    });
  });
}
