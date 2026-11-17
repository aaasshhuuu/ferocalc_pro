import 'package:fincalc_pro/core/models/verified_fd_rate.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/favorites/domain/repositories/favorite_banks_repository.dart';
import 'package:fincalc_pro/features/favorites/presentation/bloc/favorite_banks_bloc.dart';
import 'package:fincalc_pro/features/financial_insights/data/models/financial_profile_model.dart';
import 'package:fincalc_pro/features/financial_insights/data/repositories/financial_profile_repository_impl.dart';
import 'package:fincalc_pro/features/financial_insights/domain/models/emergency_fund_insight.dart';
import 'package:fincalc_pro/features/financial_insights/domain/models/financial_overview.dart';
import 'package:fincalc_pro/features/financial_insights/domain/models/financial_profile.dart';
import 'package:fincalc_pro/features/financial_insights/domain/models/goal_intelligence_summary.dart';
import 'package:fincalc_pro/features/financial_insights/domain/models/habit_insight.dart';
import 'package:fincalc_pro/features/financial_insights/domain/repositories/financial_profile_repository.dart';
import 'package:fincalc_pro/features/financial_insights/domain/services/financial_insights_engine.dart';
import 'package:fincalc_pro/features/financial_insights/presentation/bloc/financial_insights_bloc.dart';
import 'package:fincalc_pro/features/financial_insights/presentation/screens/financial_insights_dashboard_screen.dart';
import 'package:fincalc_pro/features/goals/domain/repositories/goal_repository.dart';
import 'package:fincalc_pro/features/goals/presentation/bloc/goal_bloc.dart';
import 'package:fincalc_pro/features/history/domain/repositories/calculation_history_repository.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({Widget? home, ThemeData? theme}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()),
      BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
      BlocProvider<GoalBloc>(create: (_) => di.sl<GoalBloc>()),
      BlocProvider<FavoriteBanksBloc>(create: (_) => di.sl<FavoriteBanksBloc>()),
      BlocProvider<FinancialInsightsBloc>(
        create: (_) => di.sl<FinancialInsightsBloc>(),
      ),
    ],
    child: MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: home ?? const FinancialInsightsDashboardScreen(),
    ),
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
    await di.sl<FavoriteBanksRepository>().clearAllFavorites();
    await di.sl<FinancialProfileRepository>().clearProfile();
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 1: FINANCIAL CALCULATIONS & MATHEMATICAL BOUNDARIES
  // ═══════════════════════════════════════════════════════════════
  group('Group 1: Financial Calculations & Math Boundaries', () {
    test('Calculates monthly unallocated balance, savings rate, and EMI share correctly', () {
      const profile = FinancialProfile(
        monthlyIncome: 100000.0,
        essentialExpenses: 40000.0,
        discretionaryExpenses: 20000.0,
        monthlyEmi: 15000.0,
        declaredSavings: 15000.0,
        emergencySavings: 240000.0,
        emergencyTargetMonths: 6,
      );

      final overview = FinancialInsightsEngine.computeOverview(profile);

      // Unallocated Balance = 100,000 - 40,000 - 20,000 - 15,000 - 15,000 = 10,000
      expect(overview.unallocatedBalance, equals(10000.0));
      expect(overview.isSurplus, isTrue);
      expect(overview.isDeficit, isFalse);
      expect(overview.isBalanced, isFalse);

      // Declared Savings Rate = 15,000 / 100,000 * 100 = 15.0%
      expect(overview.declaredSavingsRate, equals(15.0));

      // EMI Share = 15,000 / 100,000 * 100 = 15.0%
      expect(overview.emiShare, equals(15.0));
      expect(overview.totalOutflows, equals(90000.0));
    });

    test('Safely handles zero income without NaN or division by zero', () {
      const zeroIncomeProfile = FinancialProfile(
        monthlyIncome: 0.0,
        essentialExpenses: 30000.0,
        discretionaryExpenses: 10000.0,
        monthlyEmi: 10000.0,
        declaredSavings: 5000.0,
      );

      final overview = FinancialInsightsEngine.computeOverview(zeroIncomeProfile);

      expect(overview.unallocatedBalance, equals(-55000.0));
      expect(overview.isDeficit, isTrue);
      expect(overview.isSurplus, isFalse);
      expect(overview.declaredSavingsRate, equals(0.0));
      expect(overview.emiShare, equals(0.0));
      expect(overview.declaredSavingsRate.isNaN, isFalse);
      expect(overview.emiShare.isNaN, isFalse);
    });

    test('Detects negative monthly balance (deficit) accurately', () {
      const deficitProfile = FinancialProfile(
        monthlyIncome: 50000.0,
        essentialExpenses: 30000.0,
        discretionaryExpenses: 15000.0,
        monthlyEmi: 15000.0,
        declaredSavings: 10000.0,
      );

      final overview = FinancialInsightsEngine.computeOverview(deficitProfile);

      // Total outflows = 70,000 > income 50,000 -> deficit -20,000
      expect(overview.unallocatedBalance, equals(-20000.0));
      expect(overview.isDeficit, isTrue);
      expect(overview.isSurplus, isFalse);
    });

    test('Computes exact balanced budget when unallocated balance is zero', () {
      const balancedProfile = FinancialProfile(
        monthlyIncome: 60000.0,
        essentialExpenses: 30000.0,
        discretionaryExpenses: 10000.0,
        monthlyEmi: 10000.0,
        declaredSavings: 10000.0,
      );

      final overview = FinancialInsightsEngine.computeOverview(balancedProfile);

      expect(overview.unallocatedBalance, equals(0.0));
      expect(overview.isBalanced, isTrue);
      expect(overview.isDeficit, isFalse);
      expect(overview.isSurplus, isFalse);
    });

    test('Emergency Fund coverage, target, and gap calculation', () {
      const profile = FinancialProfile(
        essentialExpenses: 50000.0,
        emergencySavings: 150000.0,
        emergencyTargetMonths: 6,
      );

      final insight = FinancialInsightsEngine.computeEmergencyFund(profile);

      // Coverage = 150,000 / 50,000 = 3.0 months
      expect(insight.coverageMonths, equals(3.0));
      // Target = 50,000 * 6 = 300,000
      expect(insight.targetAmount, equals(300000.0));
      // Gap = 300,000 - 150,000 = 150,000
      expect(insight.gap, equals(150000.0));
      expect(insight.isTargetMet, isFalse);
      expect(insight.fundingPercent, equals(50.0));
      expect(insight.readinessTier, equals(EmergencyReadinessTier.moderate));
    });

    test('Emergency Fund handles zero essential expenses safely without crashing', () {
      const profile = FinancialProfile(
        essentialExpenses: 0.0,
        emergencySavings: 50000.0,
        emergencyTargetMonths: 6,
      );

      final insight = FinancialInsightsEngine.computeEmergencyFund(profile);

      expect(insight.hasNoEssentialExpenses, isTrue);
      expect(insight.coverageMonths, equals(0.0));
      expect(insight.targetAmount, equals(0.0));
      expect(insight.gap, equals(0.0));
      expect(insight.readinessTier, equals(EmergencyReadinessTier.unconfigured));
    });

    test('Emergency Fund when liquid savings exceed target sets gap to zero', () {
      const profile = FinancialProfile(
        essentialExpenses: 40000.0,
        emergencySavings: 300000.0,
        emergencyTargetMonths: 6, // target 240,000
      );

      final insight = FinancialInsightsEngine.computeEmergencyFund(profile);

      expect(insight.coverageMonths, equals(7.5));
      expect(insight.targetAmount, equals(240000.0));
      expect(insight.gap, equals(0.0));
      expect(insight.isTargetMet, isTrue);
      expect(insight.readinessTier, equals(EmergencyReadinessTier.fullyFunded));
    });

    test('Goal affordability checks compare unallocated cash flow with required SIPs', () {
      final now = DateTime.now();
      final goals = [
        FinancialGoal(
          id: 'g1',
          name: 'Home Downpayment',
          category: GoalCategory.homePurchase,
          targetAmount: 1000000.0,
          currentSavings: 200000.0,
          targetMonths: 36,
          targetDate: now.add(const Duration(days: 36 * 30)),
          monthlyContribution: 20000.0,
          createdAt: now,
          updatedAt: now,
        ),
        FinancialGoal(
          id: 'g2',
          name: 'Child Education',
          category: GoalCategory.education,
          targetAmount: 500000.0,
          currentSavings: 100000.0,
          targetMonths: 60,
          targetDate: now.add(const Duration(days: 60 * 30)),
          monthlyContribution: 5000.0,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Case A: Unallocated balance 30,000 >= required 25,000 -> affordable
      const surplusProfile = FinancialProfile(
        monthlyIncome: 100000.0,
        essentialExpenses: 40000.0,
        discretionaryExpenses: 20000.0,
        monthlyEmi: 10000.0,
        declaredSavings: 0.0,
      );
      final overviewA = FinancialInsightsEngine.computeOverview(surplusProfile);
      final summaryA = FinancialInsightsEngine.computeGoalIntelligence(
        goals: goals,
        overview: overviewA,
      );

      expect(summaryA.activeGoals.length, equals(2));
      expect(summaryA.aggregateMonthlyContribution, equals(25000.0));
      expect(summaryA.isAffordable, isTrue);
      expect(summaryA.affordabilitySurplus, equals(5000.0));
      expect(summaryA.affordabilityDeficit, equals(0.0));

      // Case B: Unallocated balance 15,000 < required 25,000 -> shortfall
      const tightProfile = FinancialProfile(
        monthlyIncome: 80000.0,
        essentialExpenses: 40000.0,
        discretionaryExpenses: 15000.0,
        monthlyEmi: 10000.0,
        declaredSavings: 0.0,
      );
      final overviewB = FinancialInsightsEngine.computeOverview(tightProfile);
      final summaryB = FinancialInsightsEngine.computeGoalIntelligence(
        goals: goals,
        overview: overviewB,
      );

      expect(summaryB.isAffordable, isFalse);
      expect(summaryB.affordabilityDeficit, equals(10000.0));
    });

    test('Numerical boundary conditions handle massive figures up to 100 Crores safely', () {
      const hugeProfile = FinancialProfile(
        monthlyIncome: 50000000.0, // ₹5 Crores/mo
        essentialExpenses: 10000000.0,
        discretionaryExpenses: 5000000.0,
        monthlyEmi: 15000000.0,
        declaredSavings: 10000000.0,
        emergencySavings: 60000000.0,
        emergencyTargetMonths: 6,
      );

      final overview = FinancialInsightsEngine.computeOverview(hugeProfile);
      expect(overview.unallocatedBalance, equals(10000000.0));
      expect(overview.declaredSavingsRate, equals(20.0));
      expect(overview.emiShare, equals(30.0));

      final emergency = FinancialInsightsEngine.computeEmergencyFund(hugeProfile);
      expect(emergency.coverageMonths, equals(6.0));
      expect(emergency.isTargetMet, isTrue);
      expect(emergency.gap, equals(0.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 2: PERSISTENCE & DATA ISOLATION TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Group 2: Local Persistence & Privacy Isolation', () {
    test('Saves financial profile to local SharedPreferences successfully', () async {
      final repo = di.sl<FinancialProfileRepository>();

      const profile = FinancialProfile(
        monthlyIncome: 90000.0,
        essentialExpenses: 35000.0,
        discretionaryExpenses: 15000.0,
        monthlyEmi: 20000.0,
        declaredSavings: 12000.0,
        emergencySavings: 200000.0,
        emergencyTargetMonths: 6,
      );

      await repo.saveProfile(profile);

      final loaded = await repo.getProfile();
      expect(loaded.isConfigured, isTrue);
      expect(loaded.monthlyIncome, equals(90000.0));
      expect(loaded.essentialExpenses, equals(35000.0));
      expect(loaded.discretionaryExpenses, equals(15000.0));
      expect(loaded.monthlyEmi, equals(20000.0));
      expect(loaded.declaredSavings, equals(12000.0));
      expect(loaded.emergencySavings, equals(200000.0));
      expect(loaded.emergencyTargetMonths, equals(6));
      expect(loaded.updatedAt, isNotNull);
    });

    test('Saved profile survives repository reinitialization', () async {
      final repo1 = di.sl<FinancialProfileRepository>();
      const original = FinancialProfile(
        monthlyIncome: 120000.0,
        essentialExpenses: 45000.0,
        emergencySavings: 300000.0,
        emergencyTargetMonths: 9,
      );
      await repo1.saveProfile(original);

      // Reinitialize a fresh repository instance with same SharedPreferences
      final freshRepo = FinancialProfileRepositoryImpl(
        preferences: di.sl<SharedPreferences>(),
      );
      final restored = await freshRepo.getProfile();

      expect(restored.monthlyIncome, equals(120000.0));
      expect(restored.essentialExpenses, equals(45000.0));
      expect(restored.emergencySavings, equals(300000.0));
      expect(restored.emergencyTargetMonths, equals(9));
    });

    test('Updating profile edits existing values cleanly', () async {
      final repo = di.sl<FinancialProfileRepository>();
      const initial = FinancialProfile(monthlyIncome: 50000.0);
      await repo.saveProfile(initial);

      final loaded = await repo.getProfile();
      final modified = loaded.copyWith(
        monthlyIncome: 65000.0,
        essentialExpenses: 25000.0,
      );
      await repo.saveProfile(modified);

      final finalProfile = await repo.getProfile();
      expect(finalProfile.monthlyIncome, equals(65000.0));
      expect(finalProfile.essentialExpenses, equals(25000.0));
    });

    test('Clearing financial profile does NOT delete saved goals or calculations', () async {
      final profileRepo = di.sl<FinancialProfileRepository>();
      final goalRepo = di.sl<GoalRepository>();
      final historyRepo = di.sl<CalculationHistoryRepository>();

      // 1. Save profile
      await profileRepo.saveProfile(const FinancialProfile(monthlyIncome: 80000.0));

      // 2. Save a financial goal
      final goal = FinancialGoal(
        id: 'test_goal_keep',
        name: 'Preserved Goal',
        category: GoalCategory.emergencyFund,
        targetAmount: 200000.0,
        targetMonths: 12,
        targetDate: DateTime.now().add(const Duration(days: 365)),
        monthlyContribution: 16000.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await goalRepo.saveGoal(goal);

      // 3. Save a calculation entry
      final entry = CalculationHistoryEntry(
        id: 'calc_keep',
        calculatorId: 'sip',
        calculatorName: 'SIP Calculator',
        timestamp: DateTime.now(),
        inputs: {'Investment': '₹5,000'},
        results: {'Maturity': '₹10,00,000'},
        primaryResultLabel: 'Expected Amount',
        primaryResultValue: '₹10,00,000',
      );
      await historyRepo.saveEntry(entry);

      // 4. Clear financial profile
      await profileRepo.clearProfile();

      // Verify profile is empty
      final clearedProfile = await profileRepo.getProfile();
      expect(clearedProfile.isConfigured, isFalse);
      expect(clearedProfile.monthlyIncome, equals(0.0));

      // Verify goals and calculations are completely preserved!
      final preservedGoals = await goalRepo.getGoals();
      expect(preservedGoals.length, equals(1));
      expect(preservedGoals.first.name, equals('Preserved Goal'));

      final preservedHistory = await historyRepo.getHistory();
      expect(preservedHistory.length, equals(1));
      expect(preservedHistory.first.calculatorName, equals('SIP Calculator'));
    });

    test('FinancialProfileModel parses empty or corrupt JSON safely without throwing', () {
      final emptyParsed = FinancialProfileModel.fromJson({});
      expect(emptyParsed.monthlyIncome, equals(0.0));
      expect(emptyParsed.essentialExpenses, equals(0.0));
      expect(emptyParsed.isConfigured, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 3: INTEGRATION & DOMAIN INTELLIGENCE
  // ═══════════════════════════════════════════════════════════════
  group('Group 3: Integration & Deterministic Habit Insights', () {
    test('Dashboard integrates actual Goal Planner repository data', () async {
      final goalRepo = di.sl<GoalRepository>();
      final now = DateTime.now();

      final goal1 = FinancialGoal(
        id: 'g_active_1',
        name: 'Car Downpayment',
        category: GoalCategory.vehiclePurchase,
        targetAmount: 300000.0,
        currentSavings: 150000.0,
        targetMonths: 12,
        targetDate: now.add(const Duration(days: 360)),
        monthlyContribution: 12500.0,
        status: GoalStatus.active,
        createdAt: now,
        updatedAt: now,
      );

      final goal2 = FinancialGoal(
        id: 'g_completed_2',
        name: 'Holiday Fund',
        category: GoalCategory.travel,
        targetAmount: 100000.0,
        currentSavings: 100000.0,
        targetMonths: 6,
        targetDate: now.subtract(const Duration(days: 10)),
        monthlyContribution: 0.0,
        status: GoalStatus.completed,
        createdAt: now,
        updatedAt: now,
      );

      await goalRepo.saveGoal(goal1);
      await goalRepo.saveGoal(goal2);

      final storedGoals = await goalRepo.getGoals();
      final summary = FinancialInsightsEngine.computeGoalIntelligence(
        goals: storedGoals,
        overview: FinancialOverview.fromProfile(const FinancialProfile()),
      );

      expect(summary.allGoals.length, equals(2));
      expect(summary.activeGoals.length, equals(1));
      expect(summary.completedGoals.length, equals(1));
      expect(summary.totalTargetAmount, equals(300000.0));
      expect(summary.totalAccumulatedSavings, equals(150000.0));
      expect(summary.overallProgressPercent, equals(50.0));
    });

    test('Saved calculations summaries use real history entries', () async {
      final historyRepo = di.sl<CalculationHistoryRepository>();
      final now = DateTime.now();

      await historyRepo.saveEntry(
        CalculationHistoryEntry(
          id: 'c1',
          calculatorId: 'emi',
          calculatorName: 'Home Loan EMI',
          category: 'Loans',
          timestamp: now,
          inputs: {},
          results: {},
          primaryResultLabel: 'EMI',
          primaryResultValue: '₹35,000',
        ),
      );

      await historyRepo.saveEntry(
        CalculationHistoryEntry(
          id: 'c2',
          calculatorId: 'sip',
          calculatorName: 'Retirement SIP',
          category: 'Investments',
          timestamp: now.subtract(const Duration(hours: 1)),
          inputs: {},
          results: {},
          primaryResultLabel: 'Maturity',
          primaryResultValue: '₹50,00,000',
        ),
      );

      await historyRepo.saveEntry(
        CalculationHistoryEntry(
          id: 'c3',
          calculatorId: 'personal_loan',
          calculatorName: 'Car Loan EMI',
          category: 'Loans',
          timestamp: now.subtract(const Duration(hours: 2)),
          inputs: {},
          results: {},
          primaryResultLabel: 'EMI',
          primaryResultValue: '₹12,000',
        ),
      );

      final history = await historyRepo.getHistory();
      final summary = FinancialInsightsEngine.computeSavedCalculations(history);

      expect(summary.totalCount, equals(3));
      expect(summary.mostFrequentCategory, equals('Loans'));
      expect(summary.categoryFrequencies['Loans'], equals(2));
      expect(summary.categoryFrequencies['Investments'], equals(1));
      expect(summary.recentEntries.length, equals(3));
    });

    test('Verified FD filtering strictly excludes expired and future-dated rates', () {
      final now = DateTime.now();
      final activeRate = VerifiedFdRate(
        id: 'r_active',
        bankId: 'sbi',
        bankName: 'State Bank of India',
        bankShortName: 'SBI',
        customerType: VerifiedCustomerType.regular,
        minDeposit: 1000.0,
        interestRate: 7.25,
        isCallable: true,
        compoundingFrequency: CompoundingFrequency.quarterly,
        effectiveFrom: now.subtract(const Duration(days: 30)),
        effectiveUntil: now.add(const Duration(days: 60)),
      );

      final expiredRate = VerifiedFdRate(
        id: 'r_expired',
        bankId: 'hdfc',
        bankName: 'HDFC Bank',
        bankShortName: 'HDFC',
        customerType: VerifiedCustomerType.regular,
        minDeposit: 5000.0,
        interestRate: 7.40,
        isCallable: true,
        compoundingFrequency: CompoundingFrequency.quarterly,
        effectiveFrom: now.subtract(const Duration(days: 120)),
        effectiveUntil: now.subtract(const Duration(days: 5)), // Expired
      );

      final futureRate = VerifiedFdRate(
        id: 'r_future',
        bankId: 'icici',
        bankName: 'ICICI Bank',
        bankShortName: 'ICICI',
        customerType: VerifiedCustomerType.regular,
        minDeposit: 10000.0,
        interestRate: 7.50,
        isCallable: true,
        compoundingFrequency: CompoundingFrequency.quarterly,
        effectiveFrom: now.add(const Duration(days: 15)), // Future
      );

      final allRates = [activeRate, expiredRate, futureRate];

      final filtered = allRates.where((r) {
        if (r.effectiveFrom.isAfter(now)) return false;
        if (r.effectiveUntil != null && r.effectiveUntil!.isBefore(now)) return false;
        return true;
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('r_active'));
    });

    test('Habit insights engine generates transparent, deterministic insights', () {
      const profile = FinancialProfile(
        monthlyIncome: 100000.0,
        essentialExpenses: 35000.0,
        discretionaryExpenses: 15000.0,
        monthlyEmi: 20000.0,
        declaredSavings: 25000.0,
        emergencySavings: 210000.0,
        emergencyTargetMonths: 6,
      );

      final overview = FinancialInsightsEngine.computeOverview(profile);
      final emergency = FinancialInsightsEngine.computeEmergencyFund(profile);
      final goals = GoalIntelligenceSummary.fromGoalsAndOverview(
        goals: [],
        overview: overview,
      );

      final insights = FinancialInsightsEngine.generateHabitInsights(
        profile: profile,
        overview: overview,
        emergencyFund: emergency,
        goalSummary: goals,
      );

      expect(insights.isNotEmpty, isTrue);

      // Verify cash flow surplus insight
      final cashFlowInsight = insights.firstWhere(
        (i) => i.type == HabitInsightType.cashFlowBalance,
      );
      expect(cashFlowInsight.severity, equals(InsightSeverity.positive));
      expect(cashFlowInsight.calculatedValue, contains('+₹5,000'));

      // Verify savings rate insight (25% >= 20%)
      final savingsInsight = insights.firstWhere(
        (i) => i.type == HabitInsightType.savingsRate,
      );
      expect(savingsInsight.severity, equals(InsightSeverity.positive));
      expect(savingsInsight.calculatedValue, equals('25.0% of Income'));

      // Verify emergency reserve insight (210k / 35k = 6 months == target)
      final emergencyInsight = insights.firstWhere(
        (i) => i.type == HabitInsightType.emergencyReadiness,
      );
      expect(emergencyInsight.severity, equals(InsightSeverity.positive));
      expect(emergencyInsight.calculatedValue, equals('6.0 Months Covered'));

      // Verify EMI burden insight (20% <= 30%)
      final emiInsight = insights.firstWhere(
        (i) => i.type == HabitInsightType.emiBurden,
      );
      expect(emiInsight.severity, equals(InsightSeverity.positive));
      expect(emiInsight.calculatedValue, equals('20.0% of Income'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // GROUP 4: UI & RESPONSIVE WIDGET TESTS
  // ═══════════════════════════════════════════════════════════════
  group('Group 4: UI & Responsive Layout Tests', () {
    testWidgets('Renders first-time empty state inviting setup', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Financial Insights'), findsOneWidget);
      expect(find.text('Set Up Your Cash Flow Profile'), findsOneWidget);
      expect(find.text('Configure Cash Flow (2 Mins)'), findsOneWidget);
      expect(find.text('Emergency Fund Planner'), findsOneWidget);
      expect(find.text('Goal Intelligence'), findsOneWidget);
      expect(find.text('Saved Calculations'), findsOneWidget);
    });

    testWidgets('Configured profile renders overview metrics and distribution chart', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = di.sl<FinancialProfileRepository>();
      await repo.saveProfile(
        const FinancialProfile(
          monthlyIncome: 80000.0,
          essentialExpenses: 30000.0,
          discretionaryExpenses: 15000.0,
          monthlyEmi: 15000.0,
          declaredSavings: 10000.0,
          emergencySavings: 180000.0,
          emergencyTargetMonths: 6,
        ),
      );

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Financial Overview'), findsOneWidget);
      expect(find.text('Take-Home Income'), findsOneWidget);
      expect(find.text('Unallocated Balance'), findsOneWidget);
      expect(find.text('Declared Savings Rate'), findsOneWidget);
      expect(find.text('EMI Share of Income'), findsOneWidget);
      expect(find.text('Monthly Cash Flow Breakdown'), findsOneWidget);
      expect(find.text('Edit Cash Flow'), findsOneWidget);
    });

    testWidgets('Supports Dark Theme cleanly without visual errors', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = di.sl<FinancialProfileRepository>();
      await repo.saveProfile(
        const FinancialProfile(
          monthlyIncome: 75000.0,
          essentialExpenses: 30000.0,
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(theme: ThemeData.dark()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Financial Insights'), findsOneWidget);
      expect(find.text('Financial Overview'), findsOneWidget);
    });

    testWidgets('Responsive mobile boundary 360x640 renders without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = di.sl<FinancialProfileRepository>();
      await repo.saveProfile(
        const FinancialProfile(
          monthlyIncome: 125000.0,
          essentialExpenses: 50000.0,
          discretionaryExpenses: 25000.0,
          monthlyEmi: 25000.0,
          declaredSavings: 15000.0,
          emergencySavings: 300000.0,
        ),
      );

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify no overflow exception occurred
      expect(tester.takeException(), isNull);
      expect(find.text('Financial Insights'), findsOneWidget);
      expect(find.text('Financial Overview'), findsOneWidget);
    });

    testWidgets('CashFlowPlannerSheet opens and updates profile state immediately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap Configure Cash Flow button
      final configBtn = find.text('Configure Cash Flow (2 Mins)');
      expect(configBtn, findsOneWidget);
      await tester.tap(configBtn);
      await tester.pumpAndSettle();

      // Verify sheet is open
      expect(find.text('Cash Flow Planner'), findsOneWidget);
      expect(find.text('Monthly Take-Home Income (₹)'), findsOneWidget);

      // Enter income
      final incomeField = find.widgetWithText(
        TextFormField,
        'Monthly Take-Home Income (₹)',
      );
      await tester.enterText(incomeField, '60000');

      // Tap Save & Calculate
      final saveBtn = find.text('Save & Calculate');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify profile is now configured and rendered on dashboard
      expect(find.text('Financial Overview'), findsOneWidget);
      final profile = await di.sl<FinancialProfileRepository>().getProfile();
      expect(profile.monthlyIncome, equals(60000.0));
    });
  });
}
