import 'package:fincalc_pro/features/history/data/models/calculation_history_entry.dart';

export 'package:fincalc_pro/features/history/data/models/calculation_history_entry.dart';

abstract class CalculationHistoryRepository {
  /// Returns all stored history entries, newest first.
  Future<List<CalculationHistoryEntry>> getHistory();

  /// Saves a calculation history entry, enforcing deduplication and max history limit.
  Future<void> saveEntry(CalculationHistoryEntry entry);

  /// Deletes a single history entry by its unique ID.
  Future<void> deleteEntry(String id);

  /// Clears all calculation history entries.
  Future<void> clearHistory();

  /// Maximum allowed history entries in bounded storage.
  int get maxEntries;
}
