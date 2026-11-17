import 'package:fincalc_pro/features/calculators/data/services/calculator_preferences_service.dart';
import 'package:fincalc_pro/features/calculators/domain/models/calculator_metadata.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/calculators_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group 1: Calculator Registry Completeness & Route Integrity', () {
    test('Registry contains exactly 29 calculators across all 7 categories', () {
      expect(CalculatorRegistry.totalCount, equals(29));
      expect(CalculatorRegistry.all.length, equals(29));

      // Category counts verification
      expect(CalculatorRegistry.getByCategory(CalculatorCategory.loans).length, equals(7));
      expect(CalculatorRegistry.getByCategory(CalculatorCategory.investments).length, equals(6));
      expect(CalculatorRegistry.getByCategory(CalculatorCategory.deposits).length, equals(4));
      expect(CalculatorRegistry.getByCategory(CalculatorCategory.tax).length, equals(2));
      expect(CalculatorRegistry.getByCategory(CalculatorCategory.stocks).length, equals(2));
      expect(CalculatorRegistry.getByCategory(CalculatorCategory.retirement).length, equals(3));
      expect(CalculatorRegistry.getByCategory(CalculatorCategory.other).length, equals(5));
    });

    test('Every calculator has unique ID, non-empty metadata, and valid route', () {
      final seenIds = <String>{};
      final seenRoutes = <String>{};

      for (final calc in CalculatorRegistry.all) {
        // Unique ID
        expect(seenIds.contains(calc.id), isFalse, reason: 'Duplicate ID: ${calc.id}');
        seenIds.add(calc.id);

        // Unique Route
        expect(seenRoutes.contains(calc.destinationRoute), isFalse, reason: 'Duplicate Route: ${calc.destinationRoute}');
        seenRoutes.add(calc.destinationRoute);

        // Required non-empty properties
        expect(calc.name.trim().isNotEmpty, isTrue);
        expect(calc.shortDescription.trim().isNotEmpty, isTrue);
        expect(calc.keywords.isNotEmpty, isTrue);
        expect(calc.isAvailable, isTrue);

        // Route formatting
        expect(calc.destinationRoute.startsWith('/'), isTrue);
      }
    });

    test('Best for Me FD is mapped under Deposits and points to Smart FD Discovery route', () {
      final bestForMe = CalculatorRegistry.findById('best_for_me_fd');
      expect(bestForMe, isNotNull);
      expect(bestForMe!.category, equals(CalculatorCategory.deposits));
      expect(bestForMe.destinationRoute, equals('/discovery/best-for-me'));
      expect(bestForMe.isDiscovery, isTrue);
      expect(bestForMe.badgeText, equals('Smart Match'));
    });

    test('Find by ID and find by Route lookups resolve accurately', () {
      expect(CalculatorRegistry.findById('emi')?.name, equals('EMI'));
      expect(CalculatorRegistry.findById('fd')?.name, equals('FD'));
      expect(CalculatorRegistry.findById('non_existent_id'), isNull);

      expect(CalculatorRegistry.findByRoute('/calculator/sip')?.id, equals('sip'));
      expect(CalculatorRegistry.findByRoute('/unknown_route'), isNull);
    });
  });

  group('Group 2: Search & Alias Matching Engine', () {
    test('Matches calculator by exact and case-insensitive name', () {
      final emiMatches = CalculatorRegistry.search('EMI');
      expect(emiMatches.any((c) => c.id == 'emi'), isTrue);

      final lowerMatches = CalculatorRegistry.search('fixed deposit');
      expect(lowerMatches.any((c) => c.id == 'fd'), isTrue);
    });

    test('Matches aliases and specialized search keywords', () {
      // "home loan" -> should match emi, home_loan_eligibility
      final homeLoanMatches = CalculatorRegistry.search('home loan');
      expect(homeLoanMatches.any((c) => c.id == 'emi'), isTrue);
      expect(homeLoanMatches.any((c) => c.id == 'home_loan_eligibility'), isTrue);

      // "monthly investment" -> should match sip
      final monthlyInvest = CalculatorRegistry.search('monthly investment');
      expect(monthlyInvest.any((c) => c.id == 'sip'), isTrue);

      // "tax" -> should match income_tax, gst, ppf, nps
      final taxMatches = CalculatorRegistry.search('tax');
      expect(taxMatches.any((c) => c.id == 'income_tax'), isTrue);
      expect(taxMatches.any((c) => c.id == 'gst'), isTrue);
      expect(taxMatches.any((c) => c.id == 'ppf'), isTrue);
    });

    test('Filters search within a specific category', () {
      final loanEmi = CalculatorRegistry.search('emi', category: CalculatorCategory.loans);
      expect(loanEmi.any((c) => c.id == 'emi'), isTrue);
      expect(loanEmi.any((c) => c.id == 'credit_card_emi'), isTrue);

      final depositEmi = CalculatorRegistry.search('emi', category: CalculatorCategory.deposits);
      expect(depositEmi.isEmpty, isTrue);
    });

    test('Returns empty list when search does not match anything', () {
      final emptyResults = CalculatorRegistry.search('xyz999completelyunmatchedquery');
      expect(emptyResults.isEmpty, isTrue);
    });
  });

  group('Group 3: Preferences Service — Favorites & Recently Used Persistence', () {
    late SharedPreferences prefs;
    late CalculatorPreferencesService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = CalculatorPreferencesService(preferences: prefs);
    });

    test('Initial favorites and recents are empty', () {
      expect(service.getFavoriteIds(), isEmpty);
      expect(service.getFavorites(), isEmpty);
      expect(service.getRecentIds(), isEmpty);
      expect(service.getRecentCalculators(), isEmpty);
    });

    test('Toggle favorite adds and removes correctly without duplicates', () async {
      expect(service.isFavorite('emi'), isFalse);

      await service.toggleFavorite('emi');
      expect(service.isFavorite('emi'), isTrue);
      expect(service.getFavoriteIds(), equals(['emi']));

      // Adding again does not duplicate
      await service.addFavorite('emi');
      expect(service.getFavoriteIds().length, equals(1));

      // Toggle removes
      await service.toggleFavorite('emi');
      expect(service.isFavorite('emi'), isFalse);
      expect(service.getFavoriteIds(), isEmpty);
    });

    test('Favorites persist across new service instance with same SharedPreferences', () async {
      await service.addFavorite('fd');
      await service.addFavorite('sip');

      // Create new instance simulating app restart
      final reloadedService = CalculatorPreferencesService(preferences: prefs);
      expect(reloadedService.isFavorite('fd'), isTrue);
      expect(reloadedService.isFavorite('sip'), isTrue);
      expect(reloadedService.getFavoriteIds().length, equals(2));
      expect(reloadedService.getFavorites().map((c) => c.id), containsAll(['fd', 'sip']));
    });

    test('Recently used moves repeated launches to the top without duplicates', () async {
      await service.recordLaunch('emi');
      await service.recordLaunch('fd');
      await service.recordLaunch('sip');

      expect(service.getRecentIds(), equals(['sip', 'fd', 'emi']));

      // Re-launching 'fd' moves it to index 0
      await service.recordLaunch('fd');
      expect(service.getRecentIds(), equals(['fd', 'sip', 'emi']));
    });

    test('Recently used caps history at limit (10 items)', () async {
      final testIds = [
        'emi', 'loan_amount', 'loan_term', 'interest_rate',
        'home_loan_eligibility', 'personal_loan_eligibility', 'credit_card_emi',
        'sip', 'swp', 'lumpsum', 'cagr', 'ppf',
      ];

      for (final id in testIds) {
        await service.recordLaunch(id);
      }

      final recentIds = service.getRecentIds();
      expect(recentIds.length, equals(10));
      expect(recentIds.first, equals('ppf')); // latest pushed
      expect(recentIds.contains('emi'), isFalse); // oldest pushed out
    });

    test('Clear recent resets history completely', () async {
      await service.recordLaunch('emi');
      await service.recordLaunch('fd');
      expect(service.getRecentIds().length, equals(2));

      await service.clearRecent();
      expect(service.getRecentIds(), isEmpty);
      expect(service.getRecentCalculators(), isEmpty);
    });
  });

  group('Group 4: CalculatorsHubScreen Widget & UI Tests', () {
    late SharedPreferences prefs;
    late CalculatorPreferencesService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = CalculatorPreferencesService(preferences: prefs);
    });

    Widget wrap(Widget? child, [GoRouter? router]) {
      if (router != null) {
        return MaterialApp.router(
          routerConfig: router,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF091422),
            cardColor: const Color(0xFF132235),
          ),
        );
      }
      return MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF091422),
          cardColor: const Color(0xFF132235),
        ),
        home: child!,
      );
    }

    testWidgets('Renders Search Bar, Category Chips, and All Categories', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrap(CalculatorsHubScreen(preferencesService: service)));
      await tester.pumpAndSettle();

      // App bar & Search
      expect(find.text('Calculators'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Category chips
      expect(find.text('All (29)'), findsOneWidget);
      expect(find.text('Favorites (0)'), findsOneWidget);
      expect(find.text('Loans (7)'), findsOneWidget);

      // Section titles
      expect(find.text('Loans'), findsWidgets);
      expect(find.text('Deposits'), findsWidgets);
      expect(find.text('General Interest'), findsOneWidget); // Regression guarantee
    });

    testWidgets('Tapping favorite star toggles favorite state without navigation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrap(CalculatorsHubScreen(preferencesService: service)));
      await tester.pumpAndSettle();

      final favBtn = find.byKey(const ValueKey('fav_btn_emi'));
      expect(favBtn, findsOneWidget);
      expect(service.isFavorite('emi'), isFalse);

      await tester.tap(favBtn);
      await tester.pumpAndSettle();

      expect(service.isFavorite('emi'), isTrue);
      expect(find.text('Favorites (1)'), findsOneWidget);
      expect(find.text('Pinned Favorites'), findsOneWidget);

      // Toggle back off
      await tester.tap(favBtn);
      await tester.pumpAndSettle();

      expect(service.isFavorite('emi'), isFalse);
      expect(find.text('Favorites (0)'), findsOneWidget);
    });

    testWidgets('Search query filters calculators instantly and displays empty state on miss', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrap(CalculatorsHubScreen(preferencesService: service)));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'fixed deposit');
      await tester.pumpAndSettle();

      // Should find FD and Best for Me FD
      expect(find.text('FD'), findsOneWidget);
      expect(find.text('Best for Me FD'), findsOneWidget);

      // Enter query with zero matches
      await tester.enterText(find.byType(TextField), 'xyznonexistenttool');
      await tester.pumpAndSettle();

      expect(find.text('No calculators found for "xyznonexistenttool"'), findsOneWidget);
      expect(find.text('Clear Search'), findsOneWidget);

      // Tap Clear Search button
      await tester.tap(find.text('Clear Search'));
      await tester.pumpAndSettle();

      expect(find.text('All (29)'), findsOneWidget);
    });

    testWidgets('Category filter chip isolates selected category', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrap(CalculatorsHubScreen(preferencesService: service)));
      await tester.pumpAndSettle();

      // Tap Loans category chip
      await tester.tap(find.text('Loans (7)'));
      await tester.pumpAndSettle();

      expect(find.text('EMI'), findsOneWidget);
      expect(find.text('Loan Amount'), findsOneWidget);
      expect(find.text('FD'), findsNothing);
    });

    testWidgets('Recently used section displays items and clear dialog confirms clearing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await service.recordLaunch('emi');
      await service.recordLaunch('fd');

      await tester.pumpWidget(wrap(CalculatorsHubScreen(preferencesService: service)));
      await tester.pumpAndSettle();

      expect(find.text('Recently Used'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      // Tap Clear button to show dialog
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Clear Recent History?'), findsOneWidget);

      // Confirm Clear
      await tester.tap(find.text('Clear History'));
      await tester.pumpAndSettle();

      expect(service.getRecentIds(), isEmpty);
      expect(find.text('Recently Used'), findsNothing);
    });

    testWidgets('Tapping calculator card records launch and navigates to route', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/calculators',
        routes: [
          GoRoute(
            path: '/calculators',
            builder: (ctx, state) => CalculatorsHubScreen(preferencesService: service),
          ),
          GoRoute(
            path: '/calculator/:type',
            builder: (ctx, state) {
              pushedRoute = state.uri.toString();
              return const Scaffold(body: Text('Calculator Detail'));
            },
          ),
          GoRoute(
            path: '/discovery/best-for-me',
            builder: (ctx, state) {
              pushedRoute = state.uri.toString();
              return const Scaffold(body: Text('Best for Me Discovery'));
            },
          ),
        ],
      );

      await tester.pumpWidget(wrap(null, router));
      await tester.pumpAndSettle();

      // Tap EMI card
      await tester.tap(find.byKey(const ValueKey('calc_card_emi')));
      await tester.pumpAndSettle();

      expect(pushedRoute, equals('/calculator/emi'));
      expect(service.getRecentIds().first, equals('emi'));
    });

    testWidgets('Small mobile viewport (360x640) renders without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(wrap(CalculatorsHubScreen(preferencesService: service)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
