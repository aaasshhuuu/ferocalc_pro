import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/verified_fd_rate.dart';
import '../../../../core/services/verified_rate_service.dart';
import '../../../favorites/domain/repositories/favorite_banks_repository.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../../history/domain/repositories/calculation_history_repository.dart';
import '../../domain/models/financial_profile.dart';
import '../../domain/repositories/financial_profile_repository.dart';
import '../../domain/services/financial_insights_engine.dart';
import 'financial_insights_event.dart';
import 'financial_insights_state.dart';

class FinancialInsightsBloc
    extends Bloc<FinancialInsightsEvent, FinancialInsightsState> {
  FinancialInsightsBloc({
    required this.profileRepository,
    required this.goalRepository,
    required this.historyRepository,
    required this.favoriteBanksRepository,
  }) : super(const FinancialInsightsInitial()) {
    on<LoadFinancialInsights>(_onLoad);
    on<UpdateFinancialProfile>(_onUpdateProfile);
    on<UpdateEmergencyTargetMonths>(_onUpdateEmergencyTargetMonths);
    on<ClearFinancialProfile>(_onClearProfile);
    on<RefreshVerifiedRates>(_onRefreshVerifiedRates);
  }

  final FinancialProfileRepository profileRepository;
  final GoalRepository goalRepository;
  final CalculationHistoryRepository historyRepository;
  final FavoriteBanksRepository favoriteBanksRepository;

  Future<void> _onLoad(
    LoadFinancialInsights event,
    Emitter<FinancialInsightsState> emit,
  ) async {
    if (state is! FinancialInsightsLoaded || event.forceRefresh) {
      emit(const FinancialInsightsLoading());
    }

    try {
      final profile = await profileRepository.getProfile();
      final goals = await goalRepository.getGoals();
      final history = await historyRepository.getHistory();
      final favoriteIds = await favoriteBanksRepository.getFavoriteIds();

      // Fetch top verified rates with safe error handling
      final verifiedRatesResult = await _fetchVerifiedRatesSafely();

      final stateLoaded = _recalculateState(
        profile: profile,
        goals: goals,
        history: history,
        favoriteBankIds: favoriteIds,
        verifiedRates: verifiedRatesResult.rates,
        verifiedRatesErrorMessage: verifiedRatesResult.errorMessage,
      );

      emit(stateLoaded);
    } catch (e) {
      emit(FinancialInsightsError('Failed to load financial insights: $e'));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateFinancialProfile event,
    Emitter<FinancialInsightsState> emit,
  ) async {
    try {
      await profileRepository.saveProfile(event.profile);

      if (state is FinancialInsightsLoaded) {
        final current = state as FinancialInsightsLoaded;
        final goals = await goalRepository.getGoals();
        final history = await historyRepository.getHistory();

        final updated = _recalculateState(
          profile: event.profile,
          goals: goals,
          history: history,
          favoriteBankIds: current.favoriteBankIds,
          verifiedRates: current.verifiedRates,
          verifiedRatesErrorMessage: current.verifiedRatesErrorMessage,
          userMessage: 'Cash flow profile updated successfully.',
        );
        emit(updated);
      } else {
        add(const LoadFinancialInsights(forceRefresh: true));
      }
    } catch (e) {
      emit(FinancialInsightsError('Failed to update cash flow profile: $e'));
    }
  }

  Future<void> _onUpdateEmergencyTargetMonths(
    UpdateEmergencyTargetMonths event,
    Emitter<FinancialInsightsState> emit,
  ) async {
    if (state is! FinancialInsightsLoaded) return;
    final current = state as FinancialInsightsLoaded;

    final updatedProfile = current.profile.copyWith(
      emergencyTargetMonths: event.targetMonths,
    );

    await profileRepository.saveProfile(updatedProfile);

    final goals = await goalRepository.getGoals();
    final history = await historyRepository.getHistory();

    final updated = _recalculateState(
      profile: updatedProfile,
      goals: goals,
      history: history,
      favoriteBankIds: current.favoriteBankIds,
      verifiedRates: current.verifiedRates,
      verifiedRatesErrorMessage: current.verifiedRatesErrorMessage,
    );
    emit(updated);
  }

  Future<void> _onClearProfile(
    ClearFinancialProfile event,
    Emitter<FinancialInsightsState> emit,
  ) async {
    try {
      await profileRepository.clearProfile();

      if (state is FinancialInsightsLoaded) {
        final current = state as FinancialInsightsLoaded;
        final goals = await goalRepository.getGoals();
        final history = await historyRepository.getHistory();

        final updated = _recalculateState(
          profile: FinancialProfile.empty,
          goals: goals,
          history: history,
          favoriteBankIds: current.favoriteBankIds,
          verifiedRates: current.verifiedRates,
          verifiedRatesErrorMessage: current.verifiedRatesErrorMessage,
          userMessage: 'Cash flow profile cleared.',
        );
        emit(updated);
      } else {
        add(const LoadFinancialInsights(forceRefresh: true));
      }
    } catch (e) {
      emit(FinancialInsightsError('Failed to clear profile: $e'));
    }
  }

  Future<void> _onRefreshVerifiedRates(
    RefreshVerifiedRates event,
    Emitter<FinancialInsightsState> emit,
  ) async {
    if (state is! FinancialInsightsLoaded) return;
    final current = state as FinancialInsightsLoaded;

    emit(current.copyWith(isVerifiedRatesLoading: true));

    final result = await _fetchVerifiedRatesSafely();
    final favoriteIds = await favoriteBanksRepository.getFavoriteIds();

    emit(current.copyWith(
      verifiedRates: result.rates,
      favoriteBankIds: favoriteIds,
      isVerifiedRatesLoading: false,
      verifiedRatesErrorMessage: result.errorMessage,
    ),);
  }

  FinancialInsightsLoaded _recalculateState({
    required FinancialProfile profile,
    required List<FinancialGoal> goals,
    required List<CalculationHistoryEntry> history,
    required Set<String> favoriteBankIds,
    required List<VerifiedFdRate> verifiedRates,
    String? verifiedRatesErrorMessage,
    String? userMessage,
  }) {
    final overview = FinancialInsightsEngine.computeOverview(profile);
    final emergencyFund = FinancialInsightsEngine.computeEmergencyFund(profile);
    final goalSummary = FinancialInsightsEngine.computeGoalIntelligence(
      goals: goals,
      overview: overview,
    );
    final savedCalculations =
        FinancialInsightsEngine.computeSavedCalculations(history);

    final habitInsights = FinancialInsightsEngine.generateHabitInsights(
      profile: profile,
      overview: overview,
      emergencyFund: emergencyFund,
      goalSummary: goalSummary,
    );

    return FinancialInsightsLoaded(
      profile: profile,
      overview: overview,
      emergencyFund: emergencyFund,
      goalSummary: goalSummary,
      habitInsights: habitInsights,
      savedCalculations: savedCalculations,
      verifiedRates: verifiedRates,
      favoriteBankIds: favoriteBankIds,
      verifiedRatesErrorMessage: verifiedRatesErrorMessage,
      userMessage: userMessage,
    );
  }

  /// Strictly filters rates:
  /// - Only public/verified rates (excludes DRAFT, IN_REVIEW, REJECTED, ARCHIVED)
  /// - Excludes expired rates (effectiveUntil < now)
  /// - Excludes future-dated rates (effectiveFrom > now)
  Future<({List<VerifiedFdRate> rates, String? errorMessage})>
      _fetchVerifiedRatesSafely() async {
    try {
      final rawRates = await VerifiedRateService.fetchTopVerified(limit: 15);
      final now = DateTime.now();

      final filtered = rawRates.where((r) {
        // Exclude future-dated rates
        if (r.effectiveFrom.isAfter(now)) return false;

        // Exclude expired rates
        if (r.effectiveUntil != null && r.effectiveUntil!.isBefore(now)) {
          return false;
        }

        return true;
      }).toList();

      return (rates: filtered, errorMessage: null);
    } catch (e) {
      // Backend unavailable or offline — honest empty state
      return (
        rates: <VerifiedFdRate>[],
        errorMessage: 'Verified bank rates are temporarily unavailable.',
      );
    }
  }
}
