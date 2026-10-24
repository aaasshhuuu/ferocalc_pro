import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fincalc_pro/features/history/domain/repositories/calculation_history_repository.dart';

class CalculationHistoryRepositoryImpl implements CalculationHistoryRepository {
  static const String storageKey = 'ferocalc_calculation_history';
  static const int defaultMaxEntries = 100;

  final SharedPreferences preferences;
  final int _maxEntries;
  List<CalculationHistoryEntry>? _cachedEntries;

  CalculationHistoryRepositoryImpl({
    required this.preferences,
    int maxEntries = defaultMaxEntries,
  }) : _maxEntries = maxEntries;

  @override
  int get maxEntries => _maxEntries;

  @override
  Future<List<CalculationHistoryEntry>> getHistory() async {
    if (_cachedEntries != null) {
      return List.unmodifiable(_cachedEntries!);
    }

    final rawJson = preferences.getString(storageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      _cachedEntries = [];
      return List.unmodifiable(_cachedEntries!);
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final List<CalculationHistoryEntry> loaded = [];
        for (final item in decoded) {
          try {
            if (item is Map<String, dynamic>) {
              loaded.add(CalculationHistoryEntry.fromJson(item));
            } else if (item is Map) {
              loaded.add(
                CalculationHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          } catch (entryError) {
            debugPrint('Failed to parse history entry: $entryError');
          }
        }

        // Sort newest first
        loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _cachedEntries = loaded;
        return List.unmodifiable(_cachedEntries!);
      } else {
        // Corrupted JSON structure (not a List) -> reset to empty list
        debugPrint('Calculation history store contained invalid structure. Resetting.');
        await preferences.setString(storageKey, '[]');
        _cachedEntries = [];
        return List.unmodifiable(_cachedEntries!);
      }
    } catch (e) {
      // Corrupt JSON string -> reset store gracefully without crashing
      debugPrint('Calculation history JSON corrupted: $e. Gracefully resetting store.');
      try {
        await preferences.setString(storageKey, '[]');
      } catch (_) {}
      _cachedEntries = [];
      return List.unmodifiable(_cachedEntries!);
    }
  }

  @override
  Future<void> saveEntry(CalculationHistoryEntry entry) async {
    try {
      final currentList = (await getHistory()).toList();

      // Deduplication check:
      // If the most recent calculation is for the same calculator with identical inputs
      // within 3 seconds, skip saving to prevent duplicate rapid taps.
      if (currentList.isNotEmpty) {
        final latest = currentList.first;
        final secondsDiff =
            entry.timestamp.difference(latest.timestamp).inSeconds.abs();
        if (secondsDiff <= 3 &&
            latest.calculatorId == entry.calculatorId &&
            _mapsEqual(latest.inputs, entry.inputs)) {
          return; // Deduplicated
        }
      }

      // Add to front (newest first)
      currentList.insert(0, entry);

      // Enforce history limit
      if (currentList.length > _maxEntries) {
        currentList.removeRange(_maxEntries, currentList.length);
      }

      final encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
      await preferences.setString(storageKey, encoded);
      _cachedEntries = currentList;
    } catch (e) {
      // NEVER crash the calculator on storage failure
      debugPrint('Failed to persist calculation history: $e');
    }
  }

  @override
  Future<void> deleteEntry(String id) async {
    try {
      final currentList = (await getHistory()).toList();
      currentList.removeWhere((entry) => entry.id == id);

      final encoded = jsonEncode(currentList.map((e) => e.toJson()).toList());
      await preferences.setString(storageKey, encoded);
      _cachedEntries = currentList;
    } catch (e) {
      debugPrint('Failed to delete calculation history entry: $e');
    }
  }

  @override
  Future<void> clearHistory() async {
    try {
      await preferences.setString(storageKey, '[]');
      _cachedEntries = [];
    } catch (e) {
      debugPrint('Failed to clear calculation history: $e');
    }
  }

  bool _mapsEqual(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) {
        return false;
      }
    }
    return true;
  }
}
