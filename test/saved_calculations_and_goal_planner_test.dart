import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/goal_planner_screen.dart';
import 'package:fincalc_pro/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:fincalc_pro/features/goals/domain/models/goal_projection.dart';
import 'package:fincalc_pro/features/goals/domain/repositories/goal_repository.dart';
import 'package:fincalc_pro/features/goals/presentation/bloc/goal_bloc.dart';
import 'package:fincalc_pro/features/history/domain/repositories/calculation_history_repository.dart';
import 'package:fincalc_pro/features/history/presentation/bloc/calculation_history_bloc.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await di.sl<GoalRepository>().clearAllGoals();
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 1: SAVED CALCULATIONS MANAGEMENT TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Group 1: Saved Calculations Management', () {
    test('CalculationHistoryEntry JSON serialization with customName and updatedAt', () {
      final now = DateTime(2026, 11, 12, 10, 0);
      final updated = DateTime(2026, 11, 12, 11, 30);
      final entry = CalculationHistoryEntry(
        id: 'calc_1',
        calculatorId: 'emi',
        calculatorName: 'EMI Calculator',
        customName: 'Dream Home Downpayment Loan',
        timestamp: now,
        updatedAt: updated,
        inputs: {'Principal': '₹25,00,000', 'Tenure': '20 Years'},
        results: {'Monthly EMI': '₹21,699'},
        primaryResultLabel: 'Monthly EMI',
        primaryResultValue: '₹21,699',
        category: 'Loans',
        rawInputs: {'principal': 2500000.0, 'years': 20},
      );

      final json = entry.toJson();
      expect(json['id'], 'calc_1');
      expect(json['customName'], 'Dream Home Downpayment Loan');
      expect(json['updatedAt'], updated.toIso8601String());
      expect(json['rawInputs']['principal'], 2500000.0);

      final deserialized = CalculationHistoryEntry.fromJson(json);
      expect(deserialized.id, 'calc_1');
      expect(deserialized.title, 'Dream Home Downpayment Loan');
      expect(deserialized.calculatorName, 'EMI Calculator');
      expect(deserialized.updatedAt, updated);
      expect(deserialized.getNumericInput('principal'), 2500000.0);
      expect(deserialized.getNumericInput('Principal'), 2500000.0);
    });

    test('CalculationHistoryEntry backward compatibility with legacy entries without customName', () {
      final legacyJson = {
        'id': 'legacy_1',
        'calculatorId': 'sip',
        'calculatorName': 'SIP Calculator',
        'timestamp': '2026-10-01T08:00:00.000',
        'inputs': {'Monthly SIP': '₹10,000', 'Tenure': '10 Years'},
        'results': {'Maturity Amount': '₹23,23,391'},
        'primaryResultLabel': 'Maturity Amount',
        'primaryResultValue': '₹23,23,391',
        'category': 'Investments',
      };

      final entry = CalculationHistoryEntry.fromJson(legacyJson);
      expect(entry.id, 'legacy_1');
      expect(entry.customName, isNull);
      expect(entry.title, 'SIP Calculator'); // Falls back to calculatorName
      expect(entry.updatedAt, isNull);
      expect(entry.effectiveUpdatedAt, entry.timestamp);
    });

    test('Rename saved calculation updates customName and effectiveUpdatedAt', () async {
      final repo = di.sl<CalculationHistoryRepository>();
      final entry = CalculationHistoryEntry(
        id: 'rename_test',
        calculatorId: 'fd',
        calculatorName: 'FD Calculator',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        inputs: {'Principal': '₹1,00,000'},
        results: {'Maturity': '₹1,07,186'},
        primaryResultLabel: 'Maturity Amount',
        primaryResultValue: '₹1,07,186',
      );

      await repo.saveEntry(entry);
      await repo.renameEntry('rename_test', 'Emergency Fund FD');

      final history = await repo.getHistory();
      expect(history.length, 1);
      expect(history.first.title, 'Emergency Fund FD');
      expect(history.first.customName, 'Emergency Fund FD');
      expect(history.first.updatedAt, isNotNull);
    });

    test('Duplicate saved calculation creates clone with (Copy) suffix and fresh ID', () async {
      final repo = di.sl<CalculationHistoryRepository>();
      final entry = CalculationHistoryEntry(
        id: 'orig_1',
        calculatorId: 'ppf',
        calculatorName: 'PPF Calculator',
        customName: 'Retirement PPF',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        inputs: {'Annual Deposit': '₹1,50,000'},
        results: {'Maturity': '₹40,68,209'},
        primaryResultLabel: 'Maturity Amount',
        primaryResultValue: '₹40,68,209',
      );

      await repo.saveEntry(entry);
      final duplicate = await repo.duplicateEntry('orig_1');

      expect(duplicate, isNotNull);
      expect(duplicate!.id, isNot('orig_1'));
      expect(duplicate.title, 'Retirement PPF (Copy)');
      expect(duplicate.calculatorId, 'ppf');

      final history = await repo.getHistory();
      expect(history.length, 2);
      expect(history.first.id, duplicate.id); // Duplicate placed at top
    });

    test('Update saved calculation edits inputs and recalculates timestamp', () async {
      final repo = di.sl<CalculationHistoryRepository>();
      final entry = CalculationHistoryEntry(
        id: 'update_1',
        calculatorId: 'emi',
        calculatorName: 'EMI Calculator',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        inputs: {'Loan Amount': '₹10,00,000'},
        results: {'Monthly EMI': '₹12,399'},
        primaryResultLabel: 'Monthly EMI',
        primaryResultValue: '₹12,399',
      );

      await repo.saveEntry(entry);

      final updated = entry.copyWith(
        inputs: {'Loan Amount': '₹15,00,000'},
        results: {'Monthly EMI': '₹18,599'},
        primaryResultValue: '₹18,599',
        updatedAt: DateTime.now(),
      );
      await repo.updateEntry(updated);

      final history = await repo.getHistory();
      expect(history.length, 1);
      expect(history.first.inputs['Loan Amount'], '₹15,00,000');
      expect(history.first.primaryResultValue, '₹18,599');
      expect(history.first.updatedAt, isNotNull);
    });

    test('Delete saved calculation with confirmation', () async {
      final repo = di.sl<CalculationHistoryRepository>();
      final entry = CalculationHistoryEntry(
        id: 'del_1',
        calculatorId: 'cagr',
        calculatorName: 'CAGR Calculator',
        timestamp: DateTime.now(),
        inputs: {'Initial': '₹10,000'},
        results: {'CAGR': '14.87%'},
        primaryResultLabel: 'CAGR',
        primaryResultValue: '14.87%',
      );

      await repo.saveEntry(entry);
      expect((await repo.getHistory()).length, 1);

      await repo.deleteEntry('del_1');
      expect((await repo.getHistory()).length, 0);
    });

    test('CalculationHistoryBloc handles Update, Rename, and Duplicate events', () async {
      final repo = di.sl<CalculationHistoryRepository>();
      final bloc = CalculationHistoryBloc(repository: repo);

      final entry = CalculationHistoryEntry(
        id: 'bloc_entry',
        calculatorId: 'sip',
        calculatorName: 'SIP Calculator',
        timestamp: DateTime.now(),
        inputs: {'SIP': '₹5,000'},
        results: {'Maturity': '₹11,61,695'},
        primaryResultLabel: 'Maturity',
        primaryResultValue: '₹11,61,695',
      );

      bloc.add(SaveCalculationEntry(entry));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<CalculationHistoryLoaded>());
      expect((bloc.state as CalculationHistoryLoaded).entries.length, 1);

      bloc.add(const RenameCalculationEntry('bloc_entry', 'College Fund'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((bloc.state as CalculationHistoryLoaded).entries.first.title, 'College Fund');

      bloc.add(const DuplicateCalculationEntry('bloc_entry'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect((bloc.state as CalculationHistoryLoaded).entries.length, 2);
      expect((bloc.state as CalculationHistoryLoaded).entries.first.title, 'College Fund (Copy)');

      await bloc.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 2: FINANCIAL GOAL PLANNER CALCULATION ENGINE TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Group 2: Financial Goal Planner Math & Projection Engine', () {
    test('Inflation-adjusted target formula (1 + i/100)^N', () {
      // ₹50,00,000 at 6% p.a. for 5 years
      final proj = GoalProjection.calculate(
        targetAmount: 5000000,
        currentSavings: 0,
        targetMonths: 60,
        isInflationEnabled: true,
        inflationRate: 6.0,
        expectedReturn: 12.0,
      );

      // 5000000 * (1.06)^5 = 6691127.89
      expect(proj.inflationAdjustedTarget, closeTo(6691127.89, 0.5));
    });

    test('Inflation disabled retains original target cost', () {
      final proj = GoalProjection.calculate(
        targetAmount: 5000000,
        currentSavings: 0,
        targetMonths: 60,
        isInflationEnabled: false,
        inflationRate: 6.0,
        expectedReturn: 12.0,
      );

      expect(proj.inflationAdjustedTarget, 5000000.0);
    });

    test('Zero expected return formula: monthlyContribution = remainingTarget / months', () {
      final proj = GoalProjection.calculate(
        targetAmount: 1200000,
        currentSavings: 0,
        targetMonths: 12,
        isInflationEnabled: false,
        expectedReturn: 0.0,
      );

      expect(proj.remainingGap, 1200000.0);
      expect(proj.monthlyContribution, closeTo(100000.0, 0.01));
      expect(proj.totalContributions, closeTo(1200000.0, 0.01));
      expect(proj.projectedGrowth, 0.0);
    });

    test('Positive return monthly contribution with end-of-month compounding', () {
      // Target ₹10,00,000, 5 years (60 months), 0 inflation, 12% return
      final proj = GoalProjection.calculate(
        targetAmount: 1000000,
        currentSavings: 0,
        targetMonths: 60,
        isInflationEnabled: false,
        expectedReturn: 12.0,
      );

      // monthlyRate = 1.12^(1/12) - 1 = 0.00948879
      // compoundFactor = (1 + 0.00948879)^60 = 1.76234168
      // contribution = 1000000 * 0.00948879 / (1.76234168 - 1) = 12446.90
      expect(proj.monthlyContribution, closeTo(12446.90, 1.0));
      expect(proj.totalContributions, closeTo(12446.90 * 60, 60.0));
      expect(proj.projectedGrowth, closeTo(1000000 - proj.totalContributions, 60.0));
    });

    test('Current savings compound growth reduces remaining target gap', () {
      // Target ₹20,00,000, Current savings ₹5,00,000, 5 years, 12% return, 0 inflation
      final proj = GoalProjection.calculate(
        targetAmount: 2000000,
        currentSavings: 500000,
        targetMonths: 60,
        isInflationEnabled: false,
        expectedReturn: 12.0,
      );

      // 500000 * (1.12)^5 = 881170.84
      expect(proj.futureSavingsValue, closeTo(881170.84, 1.0));
      expect(proj.remainingGap, closeTo(2000000 - 881170.84, 1.0));
      expect(proj.progressPercent, 25.0); // 5L / 20L = 25%
    });

    test('Current savings already exceeding target sets required monthly contribution to zero', () {
      final proj = GoalProjection.calculate(
        targetAmount: 500000,
        currentSavings: 600000,
        targetMonths: 36,
        isInflationEnabled: false,
        expectedReturn: 8.0,
      );

      expect(proj.remainingGap, 0.0);
      expect(proj.monthlyContribution, 0.0);
      expect(proj.totalContributions, 0.0);
      expect(proj.progressPercent, 100.0);
    });

    test('Sanitizes invalid or impossible inputs gracefully without NaN or crash', () {
      final proj = GoalProjection.calculate(
        targetAmount: -500000,
        currentSavings: -10000,
        targetMonths: 0,
        inflationRate: -5.0,
        expectedReturn: -10.0,
      );

      expect(proj.targetAmount, 0.0);
      expect(proj.currentSavings, 0.0);
      expect(proj.targetMonths, 1);
      expect(proj.remainingGap, 0.0);
      expect(proj.monthlyContribution, 0.0);
      expect(proj.monthlyContribution.isNaN, isFalse);
    });

    test('Scenario analysis simulates surplus and shortfall accurately', () {
      // Target ₹10,00,000, 60 months, 12% return, required contribution ~₹12,447
      // 1. Simulating saving ₹15,000/mo (Surplus)
      final surplusScenario = GoalProjection.simulateScenario(
        targetAmount: 1000000,
        currentSavings: 0,
        months: 60,
        isInflationEnabled: false,
        inflationRate: 0,
        expectedReturn: 12.0,
        actualMonthlyContribution: 15000,
      );

      expect(surplusScenario.isAchieved, isTrue);
      expect(surplusScenario.surplus, greaterThan(0));
      expect(surplusScenario.shortfall, 0.0);

      // 2. Simulating saving ₹8,000/mo (Shortfall)
      final shortfallScenario = GoalProjection.simulateScenario(
        targetAmount: 1000000,
        currentSavings: 0,
        months: 60,
        isInflationEnabled: false,
        inflationRate: 0,
        expectedReturn: 12.0,
        actualMonthlyContribution: 8000,
      );

      expect(shortfallScenario.isAchieved, isFalse);
      expect(shortfallScenario.shortfall, greaterThan(0));
      expect(shortfallScenario.surplus, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 3: FINANCIAL GOAL PERSISTENCE & MODEL TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Group 3: Financial Goal Persistence & Repository', () {
    test('FinancialGoal JSON round-trip and computed progress properties', () {
      final created = DateTime(2026, 11, 1, 10, 0);
      final targetDate = DateTime(2031, 11, 1, 10, 0);

      final goal = FinancialGoal(
        id: 'goal_home',
        name: 'Dream Home Downpayment',
        category: GoalCategory.homePurchase,
        targetAmount: 3000000,
        currentSavings: 750000,
        targetMonths: 60,
        targetDate: targetDate,
        isInflationEnabled: true,
        annualInflationRate: 6.0,
        expectedAnnualReturn: 12.0,
        monthlyContribution: 42500,
        status: GoalStatus.active,
        createdAt: created,
        updatedAt: created,
      );

      expect(goal.progress, 0.25);
      expect(goal.progressPercent, 25.0);
      expect(goal.isCompleted, isFalse);
      expect(goal.isAtRisk, isFalse);

      final json = goal.toJson();
      expect(json['id'], 'goal_home');
      expect(json['category'], 'homePurchase');
      expect(json['status'], 'active');

      final deserialized = FinancialGoal.fromJson(json);
      expect(deserialized.id, 'goal_home');
      expect(deserialized.category, GoalCategory.homePurchase);
      expect(deserialized.targetAmount, 3000000.0);
      expect(deserialized.currentSavings, 750000.0);
    });

    test('FinancialGoal detects at-risk goals when target date passed or nearing with low progress', () {
      final overdueGoal = FinancialGoal(
        id: 'overdue',
        name: 'Passed Goal',
        category: GoalCategory.emergencyFund,
        targetAmount: 500000,
        currentSavings: 100000,
        targetMonths: 12,
        targetDate: DateTime.now().subtract(const Duration(days: 10)),
        monthlyContribution: 10000,
        createdAt: DateTime.now().subtract(const Duration(days: 400)),
        updatedAt: DateTime.now(),
      );

      expect(overdueGoal.isAtRisk, isTrue);

      final nearingGoal = FinancialGoal(
        id: 'nearing',
        name: 'Urgent Goal',
        category: GoalCategory.travel,
        targetAmount: 200000,
        currentSavings: 50000, // 25% progress
        targetMonths: 6,
        targetDate: DateTime.now().add(const Duration(days: 30)), // 30 days left
        monthlyContribution: 25000,
        createdAt: DateTime.now().subtract(const Duration(days: 150)),
        updatedAt: DateTime.now(),
      );

      expect(nearingGoal.isAtRisk, isTrue);
    });

    test('GoalRepository saves, updates, toggles status, and updates current savings', () async {
      final repo = di.sl<GoalRepository>();
      final goal = FinancialGoal(
        id: 'repo_goal',
        name: 'Car Purchase',
        category: GoalCategory.vehiclePurchase,
        targetAmount: 800000,
        currentSavings: 200000,
        targetMonths: 36,
        targetDate: DateTime.now().add(const Duration(days: 1000)),
        monthlyContribution: 18000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo.saveGoal(goal);
      var goals = await repo.getGoals();
      expect(goals.length, 1);
      expect(goals.first.name, 'Car Purchase');

      // Update current savings
      await repo.updateGoalSavings('repo_goal', 400000);
      goals = await repo.getGoals();
      expect(goals.first.currentSavings, 400000);
      expect(goals.first.progress, 0.5);

      // Toggle status to paused
      await repo.toggleGoalStatus('repo_goal', GoalStatus.paused);
      goals = await repo.getGoals();
      expect(goals.first.status, GoalStatus.paused);

      // Delete goal
      await repo.deleteGoal('repo_goal');
      expect((await repo.getGoals()).isEmpty, isTrue);
    });

    test('GoalRepository persists across fresh repository instance', () async {
      final prefs = di.sl<SharedPreferences>();
      final repo1 = di.sl<GoalRepository>();

      final goal = FinancialGoal(
        id: 'persist_goal',
        name: 'Higher Studies',
        category: GoalCategory.education,
        targetAmount: 2000000,
        currentSavings: 500000,
        targetMonths: 48,
        targetDate: DateTime.now().add(const Duration(days: 1400)),
        monthlyContribution: 35000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repo1.saveGoal(goal);

      // Create new repo instance reading from same prefs
      final repo2 = GoalRepositoryImpl(preferences: prefs);
      final list = await repo2.getGoals();
      expect(list.length, 1);
      expect(list.first.name, 'Higher Studies');
      expect(list.first.category, GoalCategory.education);
    });

    test('GoalBloc aggregates dashboard metrics across active, completed, and at-risk goals', () async {
      final repo = di.sl<GoalRepository>();
      final bloc = GoalBloc(repository: repo);

      final goal1 = FinancialGoal(
        id: 'g1',
        name: 'Active Goal 1',
        category: GoalCategory.emergencyFund,
        targetAmount: 1000000,
        currentSavings: 250000,
        targetMonths: 24,
        targetDate: DateTime.now().add(const Duration(days: 700)),
        monthlyContribution: 30000,
        status: GoalStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final goal2 = FinancialGoal(
        id: 'g2',
        name: 'Completed Goal',
        category: GoalCategory.travel,
        targetAmount: 200000,
        currentSavings: 200000,
        targetMonths: 12,
        targetDate: DateTime.now().add(const Duration(days: 300)),
        monthlyContribution: 0,
        status: GoalStatus.completed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bloc.add(AddGoal(goal1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(AddGoal(goal2));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as GoalLoaded;
      expect(state.goals.length, 2);
      expect(state.activeGoals.length, 1);
      expect(state.completedGoals.length, 1);
      expect(state.totalTargetAmount, 1000000.0);
      expect(state.totalSavedAmount, 250000.0);
      expect(state.overallProgressPercent, 25.0);
      expect(state.totalMonthlyRequired, 30000.0);

      await bloc.close();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 4: UI & WIDGET INTEGRATION TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Group 4: UI & Widget Integration Tests', () {
    testWidgets('CalculationHistoryScreen search and category filtering', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = di.sl<CalculationHistoryRepository>();
      await repo.saveEntry(
        CalculationHistoryEntry(
          id: 'h1',
          calculatorId: 'emi',
          calculatorName: 'EMI Calculator',
          customName: 'Dream House Loan',
          timestamp: DateTime.now(),
          inputs: {'Principal': '₹50,00,000'},
          results: {'EMI': '₹45,000'},
          primaryResultLabel: 'EMI',
          primaryResultValue: '₹45,000',
          category: 'Loans',
        ),
      );
      await repo.saveEntry(
        CalculationHistoryEntry(
          id: 'h2',
          calculatorId: 'sip',
          calculatorName: 'SIP Calculator',
          customName: 'Retirement Wealth',
          timestamp: DateTime.now(),
          inputs: {'SIP': '₹20,000'},
          results: {'Corpus': '₹1,50,00,000'},
          primaryResultLabel: 'Corpus',
          primaryResultValue: '₹1,50,00,000',
          category: 'Investments',
        ),
      );

      appRouter.go('/history');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Dream House Loan'), findsOneWidget);
      expect(find.text('Retirement Wealth'), findsOneWidget);

      // Search for "House"
      await tester.enterText(find.byType(TextField).first, 'House');
      await tester.pumpAndSettle();

      expect(find.text('Dream House Loan'), findsOneWidget);
      expect(find.text('Retirement Wealth'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Dream House Loan'), findsOneWidget);
      expect(find.text('Retirement Wealth'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('GoalPlannerScreen renders tabs, empty state, and switches to planner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/calculator/goal');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(GoalPlannerScreen), findsOneWidget);
      expect(find.text('Goal Dashboard'), findsOneWidget);
      expect(find.text('Planner & Scenarios'), findsOneWidget);
      expect(find.text('No Financial Goals Yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('create_first_goal_button')), findsOneWidget);

      // Tap Create First Goal -> switches to Planner tab
      await tester.tap(find.byKey(const ValueKey('create_first_goal_button')));
      await tester.pumpAndSettle();

      expect(find.text('Target Cost of Goal'), findsOneWidget);
      expect(find.text('Monthly Contribution Required'), findsOneWidget);
      expect(find.text('SCENARIO ANALYSIS: TEST WHAT-IF'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('GoalPlannerScreen saves goal to dashboard and renders progress card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final goalRepo = di.sl<GoalRepository>();
      await goalRepo.saveGoal(
        FinancialGoal(
          id: 'ui_goal_1',
          name: 'Kids College Fund',
          category: GoalCategory.education,
          targetAmount: 2500000,
          currentSavings: 500000,
          targetMonths: 60,
          targetDate: DateTime.now().add(const Duration(days: 1800)),
          monthlyContribution: 38500,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      appRouter.go('/calculator/goal');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Kids College Fund'), findsOneWidget);
      expect(find.text('TOTAL SAVINGS PROGRESS'), findsOneWidget);
      expect(find.text('20.0% Saved'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('GoalPlannerScreen mobile 360x640 renders without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/calculator/goal');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Switch to Planner tab
      await tester.tap(find.text('Planner & Scenarios'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
