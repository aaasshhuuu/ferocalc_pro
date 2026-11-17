import 'package:equatable/equatable.dart';
import '../../domain/models/financial_profile.dart';

abstract class FinancialInsightsEvent extends Equatable {
  const FinancialInsightsEvent();

  @override
  List<Object?> get props => [];
}

/// Loads all dashboard data: profile, goals, history, favorites, and verified rates.
class LoadFinancialInsights extends FinancialInsightsEvent {
  const LoadFinancialInsights({this.forceRefresh = false});
  final bool forceRefresh;

  @override
  List<Object?> get props => [forceRefresh];
}

/// Saves updated cash flow and emergency fund inputs, immediately recalculating metrics.
class UpdateFinancialProfile extends FinancialInsightsEvent {
  const UpdateFinancialProfile(this.profile);
  final FinancialProfile profile;

  @override
  List<Object?> get props => [profile];
}

/// Updates the emergency fund target coverage months (e.g. 3, 6, 9, 12).
class UpdateEmergencyTargetMonths extends FinancialInsightsEvent {
  const UpdateEmergencyTargetMonths(this.targetMonths);
  final int targetMonths;

  @override
  List<Object?> get props => [targetMonths];
}

/// Resets the local financial profile without touching goals, history, or favorites.
class ClearFinancialProfile extends FinancialInsightsEvent {
  const ClearFinancialProfile();
}

/// Refreshes verified bank rates from the verified rate service.
class RefreshVerifiedRates extends FinancialInsightsEvent {
  const RefreshVerifiedRates();
}
