import '../models/financial_goal.dart';

export '../models/financial_goal.dart';

abstract class GoalRepository {
  /// Returns all stored goals, sorted by creation date or active status.
  Future<List<FinancialGoal>> getGoals();

  /// Saves a new financial goal to local storage.
  Future<void> saveGoal(FinancialGoal goal);

  /// Updates an existing financial goal.
  Future<void> updateGoal(FinancialGoal goal);

  /// Deletes a goal by ID.
  Future<void> deleteGoal(String id);

  /// Toggles status between Active, Paused, or Completed.
  Future<void> toggleGoalStatus(String id, GoalStatus status);

  /// Updates current savings allocated toward a goal.
  Future<void> updateGoalSavings(String id, double newSavings);

  /// Clears all stored goals.
  Future<void> clearAllGoals();
}
