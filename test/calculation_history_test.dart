import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/calculators_hub_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/emi_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/fd_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/income_tax_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/sip_calculator_screen.dart';
import 'package:fincalc_pro/features/history/data/repositories/calculation_history_repository_impl.dart';
import 'package:fincalc_pro/features/history/domain/repositories/calculation_history_repository.dart';
import 'package:fincalc_pro/features/history/presentation/bloc/calculation_history_bloc.dart';
import 'package:fincalc_pro/features/history/presentation/screens/calculation_history_detail_screen.dart';
import 'package:fincalc_pro/features/history/presentation/screens/calculation_history_screen.dart';
import 'package:fincalc_pro/features/history/presentation/widgets/calculation_history_card.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/profile_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;

Widget _buildTestApp() {
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

  setUp(() async {
    final prefs = di.sl<SharedPreferences>();
    await prefs.clear();
    await di.sl<CalculationHistoryRepository>().clearHistory();
  });

  group('1. CalculationHistoryEntry Model Tests', () {
    test('Serializes to and deserializes from JSON correctly', () {
      final now = DateTime(2026, 9, 30, 14, 30);
      final entry = CalculationHistoryEntry(
        id: 'test_1',
        calculatorId: 'emi',
        calculatorName: 'EMI Calculator',
        timestamp: now,
        inputs: {'Loan Amount': '₹10,00,000', 'Tenure': '10 Years'},
        results: {'Monthly EMI': '₹12,399', 'Total Interest': '₹4,87,833'},
        primaryResultLabel: 'Monthly EMI',
        primaryResultValue: '₹12,399',
        category: 'Loans',
      );

      final json = entry.toJson();
      expect(json['id'], 'test_1');
      expect(json['calculatorId'], 'emi');
      expect(json['primaryResultValue'], '₹12,399');

      final reconstructed = CalculationHistoryEntry.fromJson(json);
      expect(reconstructed.id, 'test_1');
      expect(reconstructed.calculatorId, 'emi');
      expect(reconstructed.calculatorName, 'EMI Calculator');
      expect(reconstructed.primaryResultLabel, 'Monthly EMI');
      expect(reconstructed.primaryResultValue, '₹12,399');
      expect(reconstructed.category, 'Loans');
      expect(reconstructed.inputs['Loan Amount'], '₹10,00,000');
      expect(reconstructed.results['Monthly EMI'], '₹12,399');
      expect(reconstructed.icon, Icons.calculate);
    });

    test('Gracefully handles missing or malformed fields in JSON', () {
      final malformed = {
        'id': 'fallback_id',
        // calculatorId and calculatorName missing
        'inputs': 'not a map',
        'results': 12345,
        'timestamp': 'invalid-date',
      };

      final entry = CalculationHistoryEntry.fromJson(malformed);
      expect(entry.id, 'fallback_id');
      expect(entry.calculatorId, 'unknown');
      expect(entry.calculatorName, 'Calculation');
      expect(entry.inputs, isEmpty);
      expect(entry.results, isEmpty);
      expect(entry.primaryResultLabel, 'Result');
      expect(entry.category, 'General');
    });

    test('Correctly resolves icons and formats date time', () {
      final pastEntry = CalculationHistoryEntry(
        id: 'e1',
        calculatorId: 'sip',
        calculatorName: 'SIP Calculator',
        timestamp: DateTime(2025, 9, 30, 9, 5),
        inputs: const {},
        results: const {},
        primaryResultLabel: 'Expected Corpus',
        primaryResultValue: '₹10,00,000',
      );

      expect(pastEntry.icon, Icons.trending_up);
      expect(pastEntry.formattedDateTime, contains('Sep'));
      expect(pastEntry.formattedDateTime, contains('2025'));

      final todayEntry = CalculationHistoryEntry(
        id: 'e2',
        calculatorId: 'emi',
        calculatorName: 'EMI Calculator',
        timestamp: DateTime.now(),
        inputs: const {},
        results: const {},
        primaryResultLabel: 'Monthly EMI',
        primaryResultValue: '₹10,000',
      );
      expect(todayEntry.formattedDateTime, contains('Today'));
    });
  });

  group('2. CalculationHistoryRepository Tests', () {
    test('Saves entry and retrieves it from history', () async {
      final repo = di.sl<CalculationHistoryRepository>();
      final entry = CalculationHistoryEntry(
        id: 'rep_1',
        calculatorId: 'fd',
        calculatorName: 'FD Calculator',
        timestamp: DateTime.now(),
        inputs: {'Deposit': '₹1,00,000'},
        results: {'Maturity': '₹1,07,186'},
        primaryResultLabel: 'Maturity Amount',
        primaryResultValue: '₹1,07,186',
      );

      await repo.saveEntry(entry);
      final history = await repo.getHistory();
      expect(history.length, 1);
      expect(history.first.id, 'rep_1');
      expect(history.first.calculatorName, 'FD Calculator');
    });

    test('Persists history across fresh repository instance', () async {
      final prefs = di.sl<SharedPreferences>();
      final repo1 = di.sl<CalculationHistoryRepository>();

      final entry = CalculationHistoryEntry(
        id: 'persist_1',
        calculatorId: 'ppf',
        calculatorName: 'PPF Calculator',
        timestamp: DateTime.now(),
        inputs: {'Annual Deposit': '₹1,50,000'},
        results: {'Maturity': '₹40,68,209'},
        primaryResultLabel: 'Maturity Amount',
        primaryResultValue: '₹40,68,209',
      );
      await repo1.saveEntry(entry);

      // Create completely new repo instance reading from same prefs
      final freshRepo = CalculationHistoryRepositoryImpl(preferences: prefs);
      final list = await freshRepo.getHistory();
      expect(list.length, 1);
      expect(list.first.id, 'persist_1');
      expect(list.first.primaryResultValue, '₹40,68,209');
    });

    test('Enforces 100-entry limit with FIFO eviction of oldest items', () async {
      final repo = di.sl<CalculationHistoryRepository>();

      // Save 105 entries sequentially
      for (int i = 1; i <= 105; i++) {
        final entry = CalculationHistoryEntry(
          id: 'item_$i',
          calculatorId: 'emi',
          calculatorName: 'EMI Calculator',
          timestamp: DateTime.now().add(Duration(seconds: i)),
          inputs: {'Loan': '₹$i'},
          results: {'EMI': '₹${i * 10}'},
          primaryResultLabel: 'EMI',
          primaryResultValue: '₹${i * 10}',
        );
        await repo.saveEntry(entry);
      }

      final history = await repo.getHistory();
      expect(history.length, 100);

      // Newest should be item_105, oldest surviving should be item_6 (item_1 to item_5 evicted)
      expect(history.first.id, 'item_105');
      expect(history.last.id, 'item_6');
      expect(history.any((entry) => entry.id == 'item_1'), isFalse);
      expect(history.any((entry) => entry.id == 'item_5'), isFalse);
    });

    test('Deduplicates identical calculation within 3 seconds', () async {
      final repo = di.sl<CalculationHistoryRepository>();
      final now = DateTime.now();

      final entry1 = CalculationHistoryEntry(
        id: 'dedup_1',
        calculatorId: 'cagr',
        calculatorName: 'CAGR Calculator',
        timestamp: now,
        inputs: {'Initial': '₹10,000', 'Final': '₹20,000'},
        results: {'CAGR': '14.87%'},
        primaryResultLabel: 'CAGR',
        primaryResultValue: '14.87%',
      );

      final entry2 = CalculationHistoryEntry(
        id: 'dedup_2',
        calculatorId: 'cagr',
        calculatorName: 'CAGR Calculator',
        timestamp: now.add(const Duration(milliseconds: 500)),
        inputs: {'Initial': '₹10,000', 'Final': '₹20,000'},
        results: {'CAGR': '14.87%'},
        primaryResultLabel: 'CAGR',
        primaryResultValue: '14.87%',
      );

      await repo.saveEntry(entry1);
      await repo.saveEntry(entry2);

      final history = await repo.getHistory();
      expect(history.length, 1);
      expect(history.first.id, 'dedup_1');
    });

    test('Allows identical calculation after 3 seconds have passed', () async {
      final repo = di.sl<CalculationHistoryRepository>();
      final now = DateTime.now();

      final entry1 = CalculationHistoryEntry(
        id: 'time_1',
        calculatorId: 'gst',
        calculatorName: 'GST Calculator',
        timestamp: now.subtract(const Duration(seconds: 4)),
        inputs: {'Amount': '₹1,000'},
        results: {'GST': '₹180'},
        primaryResultLabel: 'Total Amount',
        primaryResultValue: '₹1,180',
      );

      final entry2 = CalculationHistoryEntry(
        id: 'time_2',
        calculatorId: 'gst',
        calculatorName: 'GST Calculator',
        timestamp: now,
        inputs: {'Amount': '₹1,000'},
        results: {'GST': '₹180'},
        primaryResultLabel: 'Total Amount',
        primaryResultValue: '₹1,180',
      );

      await repo.saveEntry(entry1);
      await repo.saveEntry(entry2);

      final history = await repo.getHistory();
      expect(history.length, 2);
    });

    test('Corruption recovery: corrupt JSON gracefully resets to empty list without crashing', () async {
      final prefs = di.sl<SharedPreferences>();
      await prefs.setString(CalculationHistoryRepositoryImpl.storageKey, '<<<corrupted-json-data>>>');

      final freshRepo = CalculationHistoryRepositoryImpl(preferences: prefs);
      final history = await freshRepo.getHistory();
      expect(history, isEmpty);

      // Verify that after recovery, saving new entries works normally
      await freshRepo.saveEntry(CalculationHistoryEntry(
        id: 'recovered_1',
        calculatorId: 'sip',
        calculatorName: 'SIP Calculator',
        timestamp: DateTime.now(),
        inputs: {},
        results: {},
        primaryResultLabel: 'Corpus',
        primaryResultValue: '₹5,00,000',
      ));
      final updated = await freshRepo.getHistory();
      expect(updated.length, 1);
      expect(updated.first.id, 'recovered_1');
    });

    test('Single item deletion and Clear All works as expected', () async {
      final repo = di.sl<CalculationHistoryRepository>();

      await repo.saveEntry(CalculationHistoryEntry(
        id: 'del_1',
        calculatorId: 'rd',
        calculatorName: 'RD Calculator',
        timestamp: DateTime.now().subtract(const Duration(seconds: 5)),
        inputs: {},
        results: {},
        primaryResultLabel: 'Maturity',
        primaryResultValue: '₹50,000',
      ));

      await repo.saveEntry(CalculationHistoryEntry(
        id: 'del_2',
        calculatorId: 'fd',
        calculatorName: 'FD Calculator',
        timestamp: DateTime.now(),
        inputs: {},
        results: {},
        primaryResultLabel: 'Maturity',
        primaryResultValue: '₹1,00,000',
      ));

      expect((await repo.getHistory()).length, 2);

      // Delete single item
      await repo.deleteEntry('del_1');
      var history = await repo.getHistory();
      expect(history.length, 1);
      expect(history.first.id, 'del_2');

      // Clear all
      await repo.clearHistory();
      history = await repo.getHistory();
      expect(history, isEmpty);
    });
  });

  group('3. CalculationHistoryBloc Tests', () {
    test('Emits Loading then Loaded on LoadCalculationHistory', () async {
      final repo = di.sl<CalculationHistoryRepository>();
      await repo.saveEntry(CalculationHistoryEntry(
        id: 'bloc_1',
        calculatorId: 'emi',
        calculatorName: 'EMI Calculator',
        timestamp: DateTime.now(),
        inputs: {},
        results: {},
        primaryResultLabel: 'EMI',
        primaryResultValue: '₹15,000',
      ));

      final bloc = CalculationHistoryBloc(repository: repo);
      expect(bloc.state, isA<CalculationHistoryInitial>());

      bloc.add(const LoadCalculationHistory());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<CalculationHistoryLoading>(),
          predicate<CalculationHistoryLoaded>((state) => state.entries.length == 1),
        ]),
      );
      await bloc.close();
    });

    test('ClearAllCalculationHistory emits Loaded with empty entries', () async {
      final repo = di.sl<CalculationHistoryRepository>();
      final bloc = CalculationHistoryBloc(repository: repo);

      bloc.add(const ClearAllCalculationHistory());
      await expectLater(
        bloc.stream,
        emits(predicate<CalculationHistoryLoaded>((state) => state.entries.isEmpty)),
      );
      await bloc.close();
    });
  });

  group('4. Calculation History UI & Screen Tests', () {
    testWidgets('Empty state renders correctly with Start Calculating button navigating to /calculators', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/history');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(CalculationHistoryScreen), findsOneWidget);
      expect(find.text('No Calculation History'), findsOneWidget);
      expect(find.byKey(const ValueKey('start_calculating_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('start_calculating_button')));
      await tester.pumpAndSettle();

      // Should navigate to /calculators
      expect(find.byType(CalculatorsHubScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Displays history entries, supports Detail view, and Clear All confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = di.sl<CalculationHistoryRepository>();
      await repo.saveEntry(CalculationHistoryEntry(
        id: 'ui_entry_1',
        calculatorId: 'emi',
        calculatorName: 'EMI Calculator',
        timestamp: DateTime(2026, 9, 30, 10, 0),
        inputs: {'Loan Amount': '₹10,00,000', 'Tenure': '10 Years'},
        results: {'Monthly EMI': '₹12,399'},
        primaryResultLabel: 'Monthly EMI',
        primaryResultValue: '₹12,399',
        category: 'Loans',
      ));

      appRouter.go('/history');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(CalculationHistoryCard), findsOneWidget);
      expect(find.text('EMI Calculator'), findsOneWidget);
      expect(find.textContaining('₹12,399'), findsWidgets);

      // Tap card to open Detail Screen
      await tester.tap(find.byType(CalculationHistoryCard));
      await tester.pumpAndSettle();

      expect(find.byType(CalculationHistoryDetailScreen), findsOneWidget);
      expect(find.text('CALCULATION INPUTS'), findsOneWidget);
      expect(find.text('CALCULATED RESULTS'), findsOneWidget);
      expect(find.byKey(const ValueKey('history_open_in_calculator_button')), findsOneWidget);

      // Tap Back to return to History list
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(CalculationHistoryScreen), findsOneWidget);

      // Verify Clear All dialog
      expect(find.byKey(const ValueKey('clear_all_history_button')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('clear_all_history_button')));
      await tester.pumpAndSettle();

      expect(find.text('Clear All History?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Clear All
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      // Now list should be empty
      expect(find.text('No Calculation History'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Profile screen has Calculation History tile that navigates to /history', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/profile');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_calculation_history_tile')), findsOneWidget);
      expect(find.text('Calculation History'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('profile_calculation_history_tile')));
      await tester.tap(find.byKey(const ValueKey('profile_calculation_history_tile')));
      await tester.pumpAndSettle();

      expect(find.byType(CalculationHistoryScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('5. Real Calculator Integration Tests', () {
    testWidgets('EMI Calculator Calculate button saves entry and deduplicates rapid clicks', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/calculator/emi');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(EmiCalculatorScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('calculate_button')), findsOneWidget);

      // First tap
      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pump();

      // Rapid second tap (deduplication check)
      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      final history = await di.sl<CalculationHistoryRepository>().getHistory();
      expect(history.length, 1);
      expect(history.first.calculatorId, 'emi');
      expect(history.first.primaryResultLabel, 'Monthly EMI');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('FD Calculator Calculate button saves entry to history', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/calculator/fd');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(FdCalculatorScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('calculate_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      final history = await di.sl<CalculationHistoryRepository>().getHistory();
      expect(history.length, 1);
      expect(history.first.calculatorId, 'fd');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('SIP Calculator Calculate button saves entry to history', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/calculator/sip');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(SipCalculatorScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('calculate_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      final history = await di.sl<CalculationHistoryRepository>().getHistory();
      expect(history.length, 1);
      expect(history.first.calculatorId, 'sip');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('Income Tax Calculator Calculate button saves entry to history', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/calculator/income_tax');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(IncomeTaxCalculatorScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('calculate_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('calculate_button')));
      await tester.pumpAndSettle();

      final history = await di.sl<CalculationHistoryRepository>().getHistory();
      expect(history.length, 1);
      expect(history.first.calculatorId, 'income_tax');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
