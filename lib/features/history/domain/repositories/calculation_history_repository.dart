import 'package:fincalc_pro/features/history/data/models/calculation_history_entry.dart';

export 'package:fincalc_pro/features/history/data/models/calculation_history_entry.dart';

abstract class CalculationHistoryRepository {
  /// Returns all stored history entries, newest first.
  Future<List<CalculationHistoryEntry>> getHistory();

  /// Saves a calculation history entry, enforcing deduplication and max history limit.
  Future<void> saveEntry(CalculationHistoryEntry entry);

  /// Updates an existing calculation entry (e.g. edited inputs, results, or timestamp).
  Future<void> updateEntry(CalculationHistoryEntry entry);

  /// Renames a calculation entry with a custom user-defined name.
  Future<void> renameEntry(String id, String newName);

  /// Duplicates an existing calculation entry, returning the new duplicate.
  Future<CalculationHistoryEntry?> duplicateEntry(String id);

  /// Deletes a single history entry by its unique ID.
  Future<void> deleteEntry(String id);

  /// Clears all calculation history entries.
  Future<void> clearHistory();

  /// Maximum allowed history entries in bounded storage.
  int get maxEntries;
}
