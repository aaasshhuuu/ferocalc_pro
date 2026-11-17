import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/goal_repository.dart';

// Events
abstract class GoalEvent extends Equatable {
  const GoalEvent();

  @override
  List<Object?> get props => [];
}

class LoadGoals extends GoalEvent {
  const LoadGoals();
}

class AddGoal extends GoalEvent {
  const AddGoal(this.goal);
  final FinancialGoal goal;

  @override
  List<Object?> get props => [goal];
}

class UpdateGoalEvent extends GoalEvent {
  const UpdateGoalEvent(this.goal);
  final FinancialGoal goal;

  @override
  List<Object?> get props => [goal];
}

class DeleteGoalEvent extends GoalEvent {
  const DeleteGoalEvent(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ToggleGoalStatusEvent extends GoalEvent {
  const ToggleGoalStatusEvent(this.id, this.status);
  final String id;
  final GoalStatus status;

  @override
  List<Object?> get props => [id, status];
}

class UpdateGoalSavingsEvent extends GoalEvent {
  const UpdateGoalSavingsEvent(this.id, this.newSavings);
  final String id;
  final double newSavings;

  @override
  List<Object?> get props => [id, newSavings];
}

class ClearAllGoalsEvent extends GoalEvent {
  const ClearAllGoalsEvent();
}

// States
abstract class GoalState extends Equatable {
  const GoalState();

  @override
  List<Object?> get props => [];
}

class GoalInitial extends GoalState {
  const GoalInitial();
}

class GoalLoading extends GoalState {
  const GoalLoading();
}

class GoalLoaded extends GoalState {
  const GoalLoaded(this.goals);
  final List<FinancialGoal> goals;

  // Computed dashboard aggregations
  List<FinancialGoal> get activeGoals =>
      goals.where((g) => g.status == GoalStatus.active).toList();

  List<FinancialGoal> get completedGoals =>
      goals.where((g) => g.isCompleted || g.status == GoalStatus.completed).toList();

  List<FinancialGoal> get atRiskGoals =>
      goals.where((g) => g.isAtRisk).toList();

  double get totalTargetAmount =>
      activeGoals.fold(0.0, (sum, g) => sum + g.targetAmount);

  double get totalSavedAmount =>
      activeGoals.fold(0.0, (sum, g) => sum + g.currentSavings);

  double get overallProgressPercent => (totalTargetAmount > 0)
      ? ((totalSavedAmount / totalTargetAmount) * 100.0).clamp(0.0, 100.0)
      : 0.0;

  double get totalMonthlyRequired =>
      activeGoals.fold(0.0, (sum, g) => sum + g.monthlyContribution);

  @override
  List<Object?> get props => [goals];
}

class GoalError extends GoalState {
  const GoalError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

// BLoC
class GoalBloc extends Bloc<GoalEvent, GoalState> {
  GoalBloc({required this.repository}) : super(const GoalInitial()) {
    on<LoadGoals>(_onLoadGoals);
    on<AddGoal>(_onAddGoal);
    on<UpdateGoalEvent>(_onUpdateGoal);
    on<DeleteGoalEvent>(_onDeleteGoal);
    on<ToggleGoalStatusEvent>(_onToggleStatus);
    on<UpdateGoalSavingsEvent>(_onUpdateSavings);
    on<ClearAllGoalsEvent>(_onClearAllGoals);
  }

  final GoalRepository repository;

  Future<void> _onLoadGoals(
    LoadGoals event,
    Emitter<GoalState> emit,
  ) async {
    emit(const GoalLoading());
    try {
      final goals = await repository.getGoals();
      emit(GoalLoaded(goals));
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> _onAddGoal(
    AddGoal event,
    Emitter<GoalState> emit,
  ) async {
    try {
      await repository.saveGoal(event.goal);
      final goals = await repository.getGoals();
      emit(GoalLoaded(goals));
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> _onUpdateGoal(
    UpdateGoalEvent event,
    Emitter<GoalState> emit,
  ) async {
    try {
      await repository.updateGoal(event.goal);
      final goals = await repository.getGoals();
      emit(GoalLoaded(goals));
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> _onDeleteGoal(
    DeleteGoalEvent event,
    Emitter<GoalState> emit,
  ) async {
    try {
      await repository.deleteGoal(event.id);
      final goals = await repository.getGoals();
      emit(GoalLoaded(goals));
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> _onToggleStatus(
    ToggleGoalStatusEvent event,
    Emitter<GoalState> emit,
  ) async {
    try {
      await repository.toggleGoalStatus(event.id, event.status);
      final goals = await repository.getGoals();
      emit(GoalLoaded(goals));
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> _onUpdateSavings(
    UpdateGoalSavingsEvent event,
    Emitter<GoalState> emit,
  ) async {
    try {
      await repository.updateGoalSavings(event.id, event.newSavings);
      final goals = await repository.getGoals();
      emit(GoalLoaded(goals));
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }

  Future<void> _onClearAllGoals(
    ClearAllGoalsEvent event,
    Emitter<GoalState> emit,
  ) async {
    try {
      await repository.clearAllGoals();
      emit(const GoalLoaded([]));
    } catch (e) {
      emit(GoalError(e.toString()));
    }
  }
}
