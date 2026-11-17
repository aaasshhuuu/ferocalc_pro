import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  GoalRepositoryImpl({required this.preferences});

  static const String storageKey = 'ferocalc_financial_goals';

  final SharedPreferences preferences;
  List<FinancialGoal>? _cachedGoals;

  @override
  Future<List<FinancialGoal>> getGoals() async {
    if (_cachedGoals != null) {
      return List.unmodifiable(_cachedGoals!);
    }

    final rawJson = preferences.getString(storageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      _cachedGoals = [];
      return List.unmodifiable(_cachedGoals!);
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final List<FinancialGoal> loaded = [];
        for (final item in decoded) {
          try {
            if (item is Map<String, dynamic>) {
              loaded.add(FinancialGoal.fromJson(item));
            } else if (item is Map) {
              loaded.add(FinancialGoal.fromJson(Map<String, dynamic>.from(item)));
            }
          } catch (e) {
            debugPrint('Failed to parse goal: $e');
          }
        }
        _cachedGoals = loaded;
        return List.unmodifiable(_cachedGoals!);
      } else {
        await preferences.setString(storageKey, '[]');
        _cachedGoals = [];
        return List.unmodifiable(_cachedGoals!);
      }
    } catch (e) {
      debugPrint('Goals JSON corrupted: $e. Gracefully resetting store.');
      try {
        await preferences.setString(storageKey, '[]');
      } catch (_) {}
      _cachedGoals = [];
      return List.unmodifiable(_cachedGoals!);
    }
  }

  @override
  Future<void> saveGoal(FinancialGoal goal) async {
    try {
      final currentList = (await getGoals()).toList();
      final existingIndex = currentList.indexWhere((g) => g.id == goal.id);

      if (existingIndex != -1) {
        currentList[existingIndex] = goal.copyWith(updatedAt: DateTime.now());
      } else {
        currentList.insert(0, goal);
      }

      final encoded = jsonEncode(currentList.map((g) => g.toJson()).toList());
      await preferences.setString(storageKey, encoded);
      _cachedGoals = currentList;
    } catch (e) {
      debugPrint('Failed to persist goal: $e');
    }
  }

  @override
  Future<void> updateGoal(FinancialGoal goal) async {
    await saveGoal(goal);
  }

  @override
  Future<void> deleteGoal(String id) async {
    try {
      final currentList = (await getGoals()).toList();
      currentList.removeWhere((g) => g.id == id);

      final encoded = jsonEncode(currentList.map((g) => g.toJson()).toList());
      await preferences.setString(storageKey, encoded);
      _cachedGoals = currentList;
    } catch (e) {
      debugPrint('Failed to delete goal: $e');
    }
  }

  @override
  Future<void> toggleGoalStatus(String id, GoalStatus status) async {
    try {
      final currentList = (await getGoals()).toList();
      final index = currentList.indexWhere((g) => g.id == id);
      if (index != -1) {
        currentList[index] = currentList[index].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
        final encoded = jsonEncode(currentList.map((g) => g.toJson()).toList());
        await preferences.setString(storageKey, encoded);
        _cachedGoals = currentList;
      }
    } catch (e) {
      debugPrint('Failed to toggle goal status: $e');
    }
  }

  @override
  Future<void> updateGoalSavings(String id, double newSavings) async {
    try {
      final currentList = (await getGoals()).toList();
      final index = currentList.indexWhere((g) => g.id == id);
      if (index != -1) {
        final existing = currentList[index];
        final isNowComplete =
            existing.targetAmount > 0 && newSavings >= existing.targetAmount;
        currentList[index] = existing.copyWith(
          currentSavings: newSavings,
          status: isNowComplete ? GoalStatus.completed : existing.status,
          updatedAt: DateTime.now(),
        );
        final encoded = jsonEncode(currentList.map((g) => g.toJson()).toList());
        await preferences.setString(storageKey, encoded);
        _cachedGoals = currentList;
      }
    } catch (e) {
      debugPrint('Failed to update goal savings: $e');
    }
  }

  @override
  Future<void> clearAllGoals() async {
    try {
      await preferences.setString(storageKey, '[]');
      _cachedGoals = [];
    } catch (e) {
      debugPrint('Failed to clear goals: $e');
    }
  }
}
