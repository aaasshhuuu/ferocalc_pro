import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../bloc/financial_insights_bloc.dart';
import '../bloc/financial_insights_event.dart';
import '../bloc/financial_insights_state.dart';
import '../widgets/emergency_fund_section.dart';
import '../widgets/financial_overview_section.dart';
import '../widgets/goal_intelligence_section.dart';
import '../widgets/habit_insights_section.dart';
import '../widgets/saved_calculations_section.dart';
import '../widgets/verified_fd_opportunities_section.dart';
import 'cash_flow_planner_sheet.dart';

/// Main consumer-facing Financial Insights and Personalized Dashboard screen.
class FinancialInsightsDashboardScreen extends StatefulWidget {
  const FinancialInsightsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<FinancialInsightsDashboardScreen> createState() =>
      _FinancialInsightsDashboardScreenState();
}

class _FinancialInsightsDashboardScreenState
    extends State<FinancialInsightsDashboardScreen> {
  static const Color gold = Color(0xFFC9A96E);

  late final FinancialInsightsBloc _bloc;
  bool _ownsBloc = false;

  @override
  void initState() {
    super.initState();
    // Resolve bloc from context or GetIt
    try {
      _bloc = BlocProvider.of<FinancialInsightsBloc>(context);
    } catch (_) {
      _bloc = GetIt.I<FinancialInsightsBloc>();
      _ownsBloc = true;
    }
    _bloc.add(const LoadFinancialInsights());
  }

  @override
  void dispose() {
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  void _showCashFlowPlanner(BuildContext context, FinancialInsightsLoaded state) {
    CashFlowPlannerSheet.show(
      context,
      profile: state.profile,
      onSave: (updated) {
        _bloc.add(UpdateFinancialProfile(updated));
      },
      onClear: () {
        _bloc.add(const ClearFinancialProfile());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<FinancialInsightsBloc, FinancialInsightsState>(
        listener: (context, state) {
          if (state is FinancialInsightsLoaded && state.userMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.userMessage!),
                backgroundColor: const Color(0xFF1E293B),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: CustomAppBar(
              title: 'Financial Insights',
              actions: [
                if (state is FinancialInsightsLoaded)
                  IconButton(
                    icon: const Icon(Icons.tune_outlined, color: gold),
                    tooltip: 'Cash Flow Settings',
                    onPressed: () => _showCashFlowPlanner(context, state),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: gold),
                  tooltip: 'Refresh Dashboard',
                  onPressed: () {
                    _bloc.add(const LoadFinancialInsights(forceRefresh: true));
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: _buildBody(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, FinancialInsightsState state) {
    if (state is FinancialInsightsLoading || state is FinancialInsightsInitial) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(gold),
        ),
      );
    }

    if (state is FinancialInsightsError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _bloc.add(const LoadFinancialInsights(forceRefresh: true));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is FinancialInsightsLoaded) {
      return RefreshIndicator(
        color: gold,
        onRefresh: () async {
          _bloc.add(const LoadFinancialInsights(forceRefresh: true));
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: Responsive.screenPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section A & B: Financial Overview & Cash Flow Planner
                  FinancialOverviewSection(
                    overview: state.overview,
                    profile: state.profile,
                    onEditCashFlow: () => _showCashFlowPlanner(context, state),
                  ),
                  const SizedBox(height: 24),

                  // Section C: Emergency Fund Planner
                  EmergencyFundSection(
                    insight: state.emergencyFund,
                    onTargetMonthsChanged: (months) {
                      _bloc.add(UpdateEmergencyTargetMonths(months));
                    },
                    onEditProfile: () => _showCashFlowPlanner(context, state),
                    onOpenGoalPlanner: () => context.push('/calculator/goal'),
                  ),
                  const SizedBox(height: 24),

                  // Section D: Goal Intelligence
                  GoalIntelligenceSection(
                    summary: state.goalSummary,
                    onOpenGoalPlanner: () => context.push('/calculator/goal'),
                    onOpenGoalDetail: (goal) {
                      context.push('/calculator/goal', extra: goal);
                    },
                    onEditCashFlow: () => _showCashFlowPlanner(context, state),
                  ),
                  const SizedBox(height: 24),

                  // Section E: Savings & Financial Habits Insights
                  HabitInsightsSection(
                    insights: state.habitInsights,
                    onActionTap: (insight) {
                      if (insight.actionRoute != null) {
                        context.push(insight.actionRoute!);
                      } else if (insight.actionLabel == 'Set Up Cash Flow' ||
                          insight.actionLabel == 'Adjust Budget' ||
                          insight.actionLabel == 'Set Essential Expenses' ||
                          insight.actionLabel == 'Review Discretionary Spending') {
                        _showCashFlowPlanner(context, state);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Section F: Saved Calculations Summary & Tools
                  SavedCalculationsSection(
                    summary: state.savedCalculations,
                    onViewAllHistory: () => context.push('/history'),
                    onOpenCalculation: (entry) {
                      context.push('/history/detail', extra: entry);
                    },
                    onLaunchCalculator: (calcId) {
                      context.push('/calculator/$calcId');
                    },
                  ),
                  const SizedBox(height: 24),

                  // Section G: Verified FD Opportunities
                  VerifiedFdOpportunitiesSection(
                    verifiedRates: state.verifiedRates,
                    favoriteBankIds: state.favoriteBankIds,
                    isLoading: state.isVerifiedRatesLoading,
                    errorMessage: state.verifiedRatesErrorMessage,
                    onOpenBestForMeFd: () => context.push('/smart-fd-discovery'),
                    onOpenDataTrustCenter: () => context.push('/data-trust-center'),
                    onOpenFavoriteBanks: () => context.push('/favorites'),
                    onOpenFdCalculator: (rate) {
                      context.push(
                        '/calculator/fd',
                        extra: {
                          'interestRate': rate.interestRate,
                          'bankName': rate.bankName,
                          'isSeniorCitizen':
                              rate.customerType.name.toLowerCase().contains('senior'),
                        },
                      );
                    },
                    onRefresh: () {
                      _bloc.add(const RefreshVerifiedRates());
                    },
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
