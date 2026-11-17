import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/discovery_models.dart';
import '../../core/widgets/custom_bottom_nav.dart';
import '../../features/admin/data/models/staged_candidate.dart';
import '../../features/admin/data/services/admin_auth_service.dart';
import '../../features/admin/presentation/screens/admin_access_denied_screen.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_login_screen.dart';
import '../../features/admin/presentation/screens/candidate_review_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/calculators/data/services/calculator_preferences_service.dart';
import '../../features/calculators/presentation/screens/amortization_schedule_screen.dart';
import '../../features/calculators/presentation/screens/cagr_calculator_screen.dart';
import '../../features/calculators/presentation/screens/calculators_hub_screen.dart';
import '../../features/calculators/presentation/screens/compound_interest_calculator_screen.dart';
import '../../features/calculators/presentation/screens/credit_card_emi_screen.dart';
import '../../features/calculators/presentation/screens/dividend_yield_calculator_screen.dart';
import '../../features/calculators/presentation/screens/education_planner_screen.dart';
import '../../features/calculators/presentation/screens/emi_calculator_screen.dart';
import '../../features/calculators/presentation/screens/epf_calculator_screen.dart';
import '../../features/calculators/presentation/screens/fd_calculator_screen.dart';
import '../../features/calculators/presentation/screens/goal_planner_screen.dart';
import '../../features/calculators/presentation/screens/gst_calculator_screen.dart';
import '../../features/calculators/presentation/screens/home_loan_eligibility_screen.dart';
import '../../features/calculators/presentation/screens/income_tax_calculator_screen.dart';
import '../../features/calculators/presentation/screens/inflation_calculator_screen.dart';
import '../../features/calculators/presentation/screens/interest_rate_calculator_screen.dart';
import '../../features/calculators/presentation/screens/loan_amount_calculator_screen.dart';
import '../../features/calculators/presentation/screens/loan_term_calculator_screen.dart';
import '../../features/calculators/presentation/screens/lumpsum_calculator_screen.dart';
import '../../features/calculators/presentation/screens/nps_calculator_screen.dart';
import '../../features/calculators/presentation/screens/personal_loan_eligibility_screen.dart';
import '../../features/calculators/presentation/screens/ppf_calculator_screen.dart';
import '../../features/calculators/presentation/screens/rd_calculator_screen.dart';
import '../../features/calculators/presentation/screens/retirement_planner_screen.dart';
import '../../features/calculators/presentation/screens/savings_calculator_screen.dart';
import '../../features/calculators/presentation/screens/simple_interest_calculator_screen.dart';
import '../../features/calculators/presentation/screens/sip_calculator_screen.dart';
import '../../features/calculators/presentation/screens/ssy_schedule_screen.dart';
import '../../features/calculators/presentation/screens/stock_return_calculator_screen.dart';
import '../../features/calculators/presentation/screens/sukanya_samriddhi_screen.dart';
import '../../features/calculators/presentation/screens/swp_calculator_screen.dart';
import '../../features/compare/presentation/screens/bank_detail_screen.dart';
import '../../features/compare/presentation/screens/compare_screen.dart';
import '../../features/compare/presentation/screens/comparison_dashboard_screen.dart';
import '../../features/compare/presentation/screens/two_bank_comparison_screen.dart';
import '../../features/discovery/presentation/screens/advanced_fd_comparison_screen.dart';
import '../../features/discovery/presentation/screens/smart_fd_discovery_screen.dart';
import '../../features/favorites/presentation/screens/favorite_banks_screen.dart';
import '../../features/financial_insights/presentation/screens/financial_insights_dashboard_screen.dart';
import '../../features/goals/domain/models/financial_goal.dart';
import '../../features/history/data/models/calculation_history_entry.dart';
import '../../features/history/presentation/screens/calculation_history_detail_screen.dart';
import '../../features/history/presentation/screens/calculation_history_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/insights/presentation/screens/financial_literacy_detail_screen.dart';
import '../../features/insights/presentation/screens/financial_literacy_hub_screen.dart';
import '../../features/insights/presentation/screens/financial_management_detail_screen.dart';
import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/ad_disclosure_screen.dart';
import '../../features/profile/presentation/screens/financial_disclaimer_screen.dart';
import '../../features/profile/presentation/screens/privacy_policy_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/terms_screen.dart';
import '../../features/trust_center/presentation/screens/data_trust_center_screen.dart';
import 'route_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Maps calculator type strings to their screen widgets
Widget _getCalculatorScreen(String type) {
  switch (type) {
    case 'emi':
      return const EmiCalculatorScreen();
    case 'loan_amount':
      return const LoanAmountCalculatorScreen();
    case 'interest_rate':
      return const InterestRateCalculatorScreen();
    case 'loan_term':
      return const LoanTermCalculatorScreen();
    case 'fd':
      return const FdCalculatorScreen();
    case 'rd':
      return const RdCalculatorScreen();
    case 'savings':
      return const SavingsCalculatorScreen();
    case 'sip':
      return const SipCalculatorScreen();
    case 'swp':
      return const SwpCalculatorScreen();
    case 'lumpsum':
      return const LumpsumCalculatorScreen();
    case 'ppf':
      return const PpfCalculatorScreen();
    case 'epf':
      return const EpfCalculatorScreen();
    case 'nps':
      return const NpsCalculatorScreen();
    case 'gst':
      return const GstCalculatorScreen();
    case 'income_tax':
      return const IncomeTaxCalculatorScreen();
    case 'inflation':
      return const InflationCalculatorScreen();
    case 'retirement':
      return const RetirementPlannerScreen();
    case 'goal':
    case 'goal_planner':
      return const GoalPlannerScreen();
    case 'education':
      return const EducationPlannerScreen();
    case 'home_loan_eligibility':
      return const HomeLoanEligibilityScreen();
    case 'personal_loan_eligibility':
      return const PersonalLoanEligibilityScreen();
    case 'credit_card_emi':
      return const CreditCardEmiScreen();
    case 'sukanya':
      return const SukanyaSamriddhiScreen();
    case 'stock_return':
      return const StockReturnCalculatorScreen();
    case 'cagr':
      return const CagrCalculatorScreen();
    case 'dividend_yield':
      return const DividendYieldCalculatorScreen();
    case 'simple_interest':
      return const SimpleInterestCalculatorScreen();
    case 'compound_interest':
      return const CompoundInterestCalculatorScreen();
    case 'general_interest':
      return const SimpleInterestCalculatorScreen();
    default:
      return const EmiCalculatorScreen();
  }
}

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/splash',
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: RouteNames.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Main shell with bottom navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return _MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          name: RouteNames.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/calculators',
          name: RouteNames.calculators,
          builder: (context, state) => const CalculatorsHubScreen(),
        ),
        GoRoute(
          path: '/compare',
          name: RouteNames.compare,
          builder: (context, state) => CompareScreen(
            initialSource: state.uri.queryParameters['source'],
          ),
        ),
        GoRoute(
          path: '/insights',
          name: RouteNames.insights,
          builder: (context, state) => const InsightsScreen(),
        ),
        GoRoute(
          path: '/profile',
          name: RouteNames.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // Calculator detail routes (outside shell so they're full-screen)
    GoRoute(
      path: '/calculator/:type',
      name: RouteNames.calculatorDetail,
      builder: (context, state) {
        final type = state.pathParameters['type'] ?? 'emi';
        if (GetIt.I.isRegistered<CalculatorPreferencesService>()) {
          GetIt.I<CalculatorPreferencesService>().recordLaunch(type);
        }
        if (type == 'fd') {
          final extra = state.extra as Map<String, dynamic>?;
          final initialPrincipal = (extra?['principal'] as num?)?.toDouble() ??
              double.tryParse(state.uri.queryParameters['principal'] ?? '');
          final initialRate = (extra?['interestRate'] as num?)?.toDouble() ??
              double.tryParse(state.uri.queryParameters['interestRate'] ?? '');
          final initialYears = (extra?['years'] as num?)?.toInt() ??
              int.tryParse(state.uri.queryParameters['years'] ?? '');
          final initialMonths = (extra?['months'] as num?)?.toInt() ??
              int.tryParse(state.uri.queryParameters['months'] ?? '');
          final initialDays = (extra?['days'] as num?)?.toInt() ??
              int.tryParse(state.uri.queryParameters['days'] ?? '');
          final initialSenior = (extra?['isSeniorCitizen'] as bool?) ??
              (state.uri.queryParameters['isSeniorCitizen'] == 'true');
          final appliedBankName = extra?['bankName']?.toString() ??
              state.uri.queryParameters['bankName'];
          final appliedSourceUrl = extra?['sourceUrl']?.toString() ??
              state.uri.queryParameters['sourceUrl'];
          final appliedVerifiedAt = extra?['verifiedAt'] != null
              ? DateTime.tryParse(extra!['verifiedAt'].toString())
              : null;
          final compoundingFrequency = extra?['compoundingFrequency']?.toString() ??
              state.uri.queryParameters['compoundingFrequency'];

          return FdCalculatorScreen(
            initialPrincipal: initialPrincipal,
            initialInterestRate: initialRate,
            initialYears: initialYears,
            initialMonths: initialMonths,
            initialDays: initialDays,
            initialIsSeniorCitizen: initialSenior,
            appliedBankName: appliedBankName,
            appliedSourceUrl: appliedSourceUrl,
            appliedVerifiedAt: appliedVerifiedAt,
            appliedCompoundingFrequency: compoundingFrequency,
          );
        }

        if (type == 'goal' || type == 'goal_planner') {
          final extra = state.extra;
          if (extra is CalculationHistoryEntry) {
            return GoalPlannerScreen(initialEntry: extra);
          } else if (extra is FinancialGoal) {
            return GoalPlannerScreen(initialGoal: extra);
          } else if (extra is Map && extra['tab'] != null) {
            return GoalPlannerScreen(initialTabIndex: (extra['tab'] as num).toInt());
          }
          return const GoalPlannerScreen();
        }

        return _getCalculatorScreen(type);
      },
    ),

    // Financial Goals Dashboard & Multi-Goal Planner
    GoRoute(
      path: '/goals',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is FinancialGoal) {
          return GoalPlannerScreen(initialGoal: extra);
        } else if (extra is CalculationHistoryEntry) {
          return GoalPlannerScreen(initialEntry: extra);
        }
        return const GoalPlannerScreen();
      },
    ),

    // Amortization Schedule
    GoRoute(
      path: '/amortization-schedule',
      name: RouteNames.amortizationSchedule,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final loanAmount = (extra?['loanAmount'] as num?)?.toDouble() ??
            double.tryParse(state.uri.queryParameters['loanAmount'] ?? '') ??
            1000000.0;
        final interestRate = (extra?['interestRate'] as num?)?.toDouble() ??
            double.tryParse(state.uri.queryParameters['interestRate'] ?? '') ??
            8.5;
        final tenureMonths = (extra?['tenureMonths'] as num?)?.toInt() ??
            int.tryParse(state.uri.queryParameters['tenureMonths'] ?? '') ??
            120;
        final isFlatRate = (extra?['isFlatRate'] as bool?) ??
            (state.uri.queryParameters['isFlatRate'] == 'true');
        return AmortizationScheduleScreen(
          loanAmount: loanAmount,
          interestRate: interestRate,
          tenureMonths: tenureMonths,
          isFlatRate: isFlatRate,
        );
      },
    ),
    GoRoute(
      path: '/calculator/emi/schedule',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final loanAmount = (extra?['loanAmount'] as num?)?.toDouble() ??
            double.tryParse(state.uri.queryParameters['loanAmount'] ?? '') ??
            1000000.0;
        final interestRate = (extra?['interestRate'] as num?)?.toDouble() ??
            double.tryParse(state.uri.queryParameters['interestRate'] ?? '') ??
            8.5;
        final tenureMonths = (extra?['tenureMonths'] as num?)?.toInt() ??
            int.tryParse(state.uri.queryParameters['tenureMonths'] ?? '') ??
            120;
        final isFlatRate = (extra?['isFlatRate'] as bool?) ??
            (state.uri.queryParameters['isFlatRate'] == 'true');
        return AmortizationScheduleScreen(
          loanAmount: loanAmount,
          interestRate: interestRate,
          tenureMonths: tenureMonths,
          isFlatRate: isFlatRate,
        );
      },
    ),

    // Sukanya Samriddhi Year-wise Schedule
    GoRoute(
      path: '/calculator/sukanya/schedule',
      name: RouteNames.ssySchedule,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final girlAge = (extra?['girlAge'] as num?)?.toInt() ??
            int.tryParse(state.uri.queryParameters['girlAge'] ?? '') ??
            0;
        final interestRate = (extra?['interestRate'] as num?)?.toDouble() ??
            double.tryParse(state.uri.queryParameters['interestRate'] ?? '') ??
            8.2;
        final yearlyDeposits = (extra?['yearlyDeposits'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            (state.uri.queryParameters['yearlyDeposit'] != null
                ? List.filled(
                    15,
                    double.tryParse(
                          state.uri.queryParameters['yearlyDeposit']!,
                        ) ??
                        150000.0,
                  )
                : List.filled(15, 150000.0));
        final isVariable = (extra?['isVariable'] as bool?) ?? false;

        return SsyScheduleScreen(
          girlAge: girlAge,
          interestRate: interestRate,
          yearlyDeposits: yearlyDeposits,
          isVariable: isVariable,
        );
      },
    ),
    GoRoute(
      path: '/ssy-schedule',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final girlAge = (extra?['girlAge'] as num?)?.toInt() ??
            int.tryParse(state.uri.queryParameters['girlAge'] ?? '') ??
            0;
        final interestRate = (extra?['interestRate'] as num?)?.toDouble() ??
            double.tryParse(state.uri.queryParameters['interestRate'] ?? '') ??
            8.2;
        final yearlyDeposits = (extra?['yearlyDeposits'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            (state.uri.queryParameters['yearlyDeposit'] != null
                ? List.filled(
                    15,
                    double.tryParse(
                          state.uri.queryParameters['yearlyDeposit']!,
                        ) ??
                        150000.0,
                  )
                : List.filled(15, 150000.0));
        final isVariable = (extra?['isVariable'] as bool?) ?? false;

        return SsyScheduleScreen(
          girlAge: girlAge,
          interestRate: interestRate,
          yearlyDeposits: yearlyDeposits,
          isVariable: isVariable,
        );
      },
    ),

    // Comparison dashboard
    GoRoute(
      path: '/comparison-dashboard',
      name: RouteNames.comparisonDashboard,
      builder: (context, state) => const ComparisonDashboardScreen(),
    ),

    // Two Bank Side-by-Side Comparison
    GoRoute(
      path: '/compare/two-banks',
      name: RouteNames.twoBankCompare,
      builder: (context, state) {
        final bankAId = state.uri.queryParameters['bankA'];
        final bankBId = state.uri.queryParameters['bankB'];
        return TwoBankComparisonScreen(
          initialBankAId: bankAId,
          initialBankBId: bankBId,
        );
      },
    ),

    // Smart FD Discovery (Best for Me)
    GoRoute(
      path: '/discovery/best-for-me',
      name: RouteNames.smartFdDiscovery,
      builder: (context, state) {
        if (GetIt.I.isRegistered<CalculatorPreferencesService>()) {
          GetIt.I<CalculatorPreferencesService>().recordLaunch('best_for_me_fd');
        }
        final extra = state.extra as Map<String, dynamic>?;
        final deposit = (extra?['depositAmount'] as num?)?.toDouble() ??
            double.tryParse(state.uri.queryParameters['deposit'] ?? '');
        final tenureYears = (extra?['tenureYears'] as num?)?.toInt() ??
            int.tryParse(state.uri.queryParameters['tenureYears'] ?? '');
        final isSenior = (extra?['isSeniorCitizen'] as bool?) ??
            (state.uri.queryParameters['isSenior'] == 'true');
        final bankId = extra?['bankId']?.toString() ??
            state.uri.queryParameters['bankId'];

        return SmartFdDiscoveryScreen(
          initialDepositAmount: deposit,
          initialTenureYears: tenureYears,
          initialIsSeniorCitizen: isSenior,
          initialBankId: bankId,
        );
      },
    ),

    // Advanced FD Comparison
    GoRoute(
      path: '/discovery/compare',
      name: RouteNames.advancedFdCompare,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final matches = (extra?['matches'] as List<dynamic>?)
                ?.map((e) => e as FdDiscoveryMatch)
                .toList() ??
            const <FdDiscoveryMatch>[];
        final criteria = extra?['criteria'] as FdDiscoveryCriteria? ??
            const FdDiscoveryCriteria();

        return AdvancedFdComparisonScreen(
          selectedMatches: matches,
          criteria: criteria,
        );
      },
    ),

    // Bank Detail Screen
    GoRoute(
      path: '/bank/:name',
      name: 'bankDetail',
      builder: (context, state) {
        final bankName = state.pathParameters['name'] ?? '';
        return BankDetailScreen(bankName: Uri.decodeComponent(bankName));
      },
    ),

    // Data Trust Center (publicly accessible consumer screen)
    GoRoute(
      path: '/trust-center',
      name: RouteNames.dataTrustCenter,
      builder: (context, state) {
        final tabStr = state.uri.queryParameters['tab'];
        final tab = tabStr != null ? (int.tryParse(tabStr) ?? 0) : 0;
        final bankId = state.uri.queryParameters['bankId'];
        return DataTrustCenterScreen(
          initialTab: tab,
          initialBankId: bankId,
        );
      },
    ),
    GoRoute(
      path: '/data-trust-center',
      builder: (context, state) {
        final tabStr = state.uri.queryParameters['tab'];
        final tab = tabStr != null ? (int.tryParse(tabStr) ?? 0) : 0;
        final bankId = state.uri.queryParameters['bankId'];
        return DataTrustCenterScreen(
          initialTab: tab,
          initialBankId: bankId,
        );
      },
    ),

    // Privacy Policy (publicly accessible on web)
    GoRoute(
      path: '/privacy',
      name: 'privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/privacy-policy',
      name: 'privacyPolicy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),

    // Terms of Use
    GoRoute(
      path: '/terms',
      name: RouteNames.terms,
      builder: (context, state) => const TermsScreen(),
    ),
    GoRoute(
      path: '/terms-of-use',
      name: 'termsOfUse',
      builder: (context, state) => const TermsScreen(),
    ),

    // Financial Disclaimers
    GoRoute(
      path: '/financial-disclaimer',
      name: RouteNames.financialDisclaimer,
      builder: (context, state) => const FinancialDisclaimerScreen(),
    ),

    // Advertising Disclosures
    GoRoute(
      path: '/ad-disclosure',
      name: RouteNames.adDisclosure,
      builder: (context, state) => const AdDisclosureScreen(),
    ),

    // Calculation History
    GoRoute(
      path: '/history',
      name: RouteNames.history,
      builder: (context, state) => const CalculationHistoryScreen(),
    ),
    GoRoute(
      path: '/history/detail',
      name: RouteNames.historyDetail,
      builder: (context, state) {
        final entry = state.extra as CalculationHistoryEntry;
        return CalculationHistoryDetailScreen(entry: entry);
      },
    ),

    // Financial Management Topic Detail
    GoRoute(
      path: '/insights/financial-management/:topicId',
      name: RouteNames.financialManagementDetail,
      builder: (context, state) {
        final topicId = state.pathParameters['topicId'] ?? '';
        return FinancialManagementDetailScreen(topicId: topicId);
      },
    ),

    // Financial Literacy Hub and Detail
    GoRoute(
      path: '/financial-literacy',
      name: RouteNames.financialLiteracyHub,
      builder: (context, state) => const FinancialLiteracyHubScreen(),
      routes: [
        GoRoute(
          path: ':topicId',
          name: RouteNames.financialLiteracyDetail,
          builder: (context, state) {
            final topicId = state.pathParameters['topicId'] ?? '';
            return FinancialLiteracyDetailScreen(topicId: topicId);
          },
        ),
      ],
    ),

    // Notifications Screen
    GoRoute(
      path: '/notifications',
      name: RouteNames.notifications,
      builder: (context, state) => const NotificationsScreen(),
    ),

    // Favorite Banks & Catalog Screen
    GoRoute(
      path: '/profile/favorites',
      name: RouteNames.favoriteBanks,
      builder: (context, state) {
        final tabStr = state.uri.queryParameters['tab'];
        final tab = tabStr == 'catalog' ? 1 : 0;
        return FavoriteBanksScreen(initialTab: tab);
      },
    ),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoriteBanksScreen(),
    ),

    // Notification Settings Screen
    GoRoute(
      path: '/settings/notifications',
      name: RouteNames.notificationSettings,
      builder: (context, state) => const NotificationSettingsScreen(),
    ),

    // Financial Insights & Personalized Dashboard
    GoRoute(
      path: '/financial-insights',
      name: RouteNames.financialInsights,
      builder: (context, state) => const FinancialInsightsDashboardScreen(),
    ),

    // Admin Console Routes (guarded against unauthorized access)
    GoRoute(
      path: '/admin',
      name: RouteNames.adminDashboard,
      builder: (context, state) => _guardedAdminRoute(const AdminDashboardScreen(initialTab: 0)),
    ),
    GoRoute(
      path: '/admin/queue',
      name: RouteNames.adminQueue,
      builder: (context, state) => _guardedAdminRoute(const AdminDashboardScreen(initialTab: 0)),
    ),
    GoRoute(
      path: '/admin/review',
      name: RouteNames.adminCandidateReview,
      builder: (context, state) {
        final candidate = state.extra as StagedCandidate?;
        if (candidate == null) {
          return _guardedAdminRoute(const AdminDashboardScreen());
        }
        return _guardedAdminRoute(CandidateReviewScreen(candidate: candidate));
      },
    ),
    GoRoute(
      path: '/admin/login',
      name: RouteNames.adminLogin,
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: '/admin/access-denied',
      name: RouteNames.adminAccessDenied,
      builder: (context, state) => const AdminAccessDeniedScreen(),
    ),
  ],
);

/// Helper ensuring admin routes are protected against unauthorized deep-link access.
Widget _guardedAdminRoute(Widget target) {
  try {
    if (!GetIt.instance.isRegistered<AdminAuthService>()) {
      return const AdminAccessDeniedScreen();
    }
    final authService = GetIt.instance<AdminAuthService>();
    if (!authService.isAuthenticated || !authService.currentSession!.isAuthorized) {
      return const AdminAccessDeniedScreen();
    }
    return target;
  } catch (_) {
    return const AdminAccessDeniedScreen();
  }
}

/// Main shell with bottom navigation bar
class _MainShell extends StatelessWidget {
  const _MainShell({required this.child});
  final Widget child;

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/calculators')) return 1;
    if (location.startsWith('/compare')) return 2;
    if (location.startsWith('/insights')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/calculators');
        break;
      case 2:
        context.go('/compare');
        break;
      case 3:
        context.go('/insights');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: CustomBottomNav(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(index, context),
      ),
    );
  }
}
