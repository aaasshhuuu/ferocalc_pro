import 'package:equatable/equatable.dart';

import '../../../../core/models/verified_fd_rate.dart';
import '../../domain/models/emergency_fund_insight.dart';
import '../../domain/models/financial_overview.dart';
import '../../domain/models/financial_profile.dart';
import '../../domain/models/goal_intelligence_summary.dart';
import '../../domain/models/habit_insight.dart';
import '../../domain/models/saved_calculations_summary.dart';

abstract class FinancialInsightsState extends Equatable {
  const FinancialInsightsState();

  @override
  List<Object?> get props => [];
}

class FinancialInsightsInitial extends FinancialInsightsState {
  const FinancialInsightsInitial();
}

class FinancialInsightsLoading extends FinancialInsightsState {
  const FinancialInsightsLoading();
}

class FinancialInsightsLoaded extends FinancialInsightsState {
  const FinancialInsightsLoaded({
    required this.profile,
    required this.overview,
    required this.emergencyFund,
    required this.goalSummary,
    required this.habitInsights,
    required this.savedCalculations,
    required this.verifiedRates,
    required this.favoriteBankIds,
    this.isVerifiedRatesLoading = false,
    this.verifiedRatesErrorMessage,
    this.userMessage,
  });

  final FinancialProfile profile;
  final FinancialOverview overview;
  final EmergencyFundInsight emergencyFund;
  final GoalIntelligenceSummary goalSummary;
  final List<HabitInsight> habitInsights;
  final SavedCalculationsSummary savedCalculations;
  final List<VerifiedFdRate> verifiedRates;
  final Set<String> favoriteBankIds;
  final bool isVerifiedRatesLoading;
  final String? verifiedRatesErrorMessage;
  final String? userMessage;

  FinancialInsightsLoaded copyWith({
    FinancialProfile? profile,
    FinancialOverview? overview,
    EmergencyFundInsight? emergencyFund,
    GoalIntelligenceSummary? goalSummary,
    List<HabitInsight>? habitInsights,
    SavedCalculationsSummary? savedCalculations,
    List<VerifiedFdRate>? verifiedRates,
    Set<String>? favoriteBankIds,
    bool? isVerifiedRatesLoading,
    String? verifiedRatesErrorMessage,
    String? userMessage,
  }) {
    return FinancialInsightsLoaded(
      profile: profile ?? this.profile,
      overview: overview ?? this.overview,
      emergencyFund: emergencyFund ?? this.emergencyFund,
      goalSummary: goalSummary ?? this.goalSummary,
      habitInsights: habitInsights ?? this.habitInsights,
      savedCalculations: savedCalculations ?? this.savedCalculations,
      verifiedRates: verifiedRates ?? this.verifiedRates,
      favoriteBankIds: favoriteBankIds ?? this.favoriteBankIds,
      isVerifiedRatesLoading:
          isVerifiedRatesLoading ?? this.isVerifiedRatesLoading,
      verifiedRatesErrorMessage:
          verifiedRatesErrorMessage ?? this.verifiedRatesErrorMessage,
      userMessage: userMessage,
    );
  }

  @override
  List<Object?> get props => [
        profile,
        overview,
        emergencyFund,
        goalSummary,
        habitInsights,
        savedCalculations,
        verifiedRates,
        favoriteBankIds,
        isVerifiedRatesLoading,
        verifiedRatesErrorMessage,
        userMessage,
      ];
}

class FinancialInsightsError extends FinancialInsightsState {
  const FinancialInsightsError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
