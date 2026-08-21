import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/calculators/presentation/screens/calculators_hub_screen.dart';
import '../../features/calculators/presentation/screens/emi_calculator_screen.dart';
import '../../features/calculators/presentation/screens/fd_calculator_screen.dart';
import '../../features/calculators/presentation/screens/rd_calculator_screen.dart';
import '../../features/calculators/presentation/screens/sip_calculator_screen.dart';
import '../../features/calculators/presentation/screens/swp_calculator_screen.dart';
import '../../features/calculators/presentation/screens/lumpsum_calculator_screen.dart';
import '../../features/calculators/presentation/screens/ppf_calculator_screen.dart';
import '../../features/calculators/presentation/screens/epf_calculator_screen.dart';
import '../../features/calculators/presentation/screens/nps_calculator_screen.dart';
import '../../features/calculators/presentation/screens/gst_calculator_screen.dart';
import '../../features/calculators/presentation/screens/income_tax_calculator_screen.dart';
import '../../features/calculators/presentation/screens/inflation_calculator_screen.dart';
import '../../features/calculators/presentation/screens/retirement_planner_screen.dart';
import '../../features/calculators/presentation/screens/goal_planner_screen.dart';
import '../../features/calculators/presentation/screens/education_planner_screen.dart';
import '../../features/calculators/presentation/screens/home_loan_eligibility_screen.dart';
import '../../features/calculators/presentation/screens/personal_loan_eligibility_screen.dart';
import '../../features/calculators/presentation/screens/credit_card_emi_screen.dart';
import '../../features/calculators/presentation/screens/loan_amount_calculator_screen.dart';
import '../../features/calculators/presentation/screens/interest_rate_calculator_screen.dart';
import '../../features/calculators/presentation/screens/loan_term_calculator_screen.dart';
import '../../features/calculators/presentation/screens/savings_calculator_screen.dart';
import '../../features/calculators/presentation/screens/sukanya_samriddhi_screen.dart';
import '../../features/calculators/presentation/screens/stock_return_calculator_screen.dart';
import '../../features/calculators/presentation/screens/cagr_calculator_screen.dart';
import '../../features/calculators/presentation/screens/dividend_yield_calculator_screen.dart';
import '../../features/compare/presentation/screens/compare_screen.dart';
import '../../features/compare/presentation/screens/comparison_dashboard_screen.dart';
import '../../features/compare/presentation/screens/bank_detail_screen.dart';
import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../core/widgets/custom_bottom_nav.dart';

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
    GoRoute(
      path: '/login',
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
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
          builder: (context, state) => const CompareScreen(),
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
        return _getCalculatorScreen(type);
      },
    ),

    // Comparison dashboard
    GoRoute(
      path: '/comparison-dashboard',
      name: RouteNames.comparisonDashboard,
      builder: (context, state) => const ComparisonDashboardScreen(),
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
  ],
);

/// Main shell with bottom navigation bar
class _MainShell extends StatelessWidget {
  final Widget child;
  const _MainShell({required this.child});

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
