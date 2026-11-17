import '../../../history/data/models/calculation_history_entry.dart';

/// Aggregated, non-sensitive summary of local calculation history.
class SavedCalculationsSummary {
  const SavedCalculationsSummary({
    required this.totalCount,
    required this.recentlyUsedCategories,
    required this.categoryFrequencies,
    required this.mostFrequentCategory,
    required this.recentEntries,
  });

  /// Total count of saved calculations stored on device.
  final int totalCount;

  /// Ordered list of unique categories recently accessed.
  final List<String> recentlyUsedCategories;

  /// Count of saved records grouped by calculator category.
  final Map<String, int> categoryFrequencies;

  /// Category with the highest frequency, if any.
  final String? mostFrequentCategory;

  /// Most recent calculation snapshots (capped at 5) for quick navigation.
  final List<CalculationHistoryEntry> recentEntries;

  static SavedCalculationsSummary fromHistory(
    List<CalculationHistoryEntry> history,
  ) {
    if (history.isEmpty) {
      return const SavedCalculationsSummary(
        totalCount: 0,
        recentlyUsedCategories: [],
        categoryFrequencies: {},
        mostFrequentCategory: null,
        recentEntries: [],
      );
    }

    final total = history.length;
    final recent = history.take(5).toList();

    final recentCategories = <String>[];
    final frequencies = <String, int>{};

    for (final entry in history) {
      final category = (entry.category != null && entry.category!.trim().isNotEmpty)
          ? entry.category!.trim()
          : 'General';

      if (!recentCategories.contains(category) && recentCategories.length < 4) {
        recentCategories.add(category);
      }

      frequencies[category] = (frequencies[category] ?? 0) + 1;
    }

    String? topCategory;
    int maxCount = -1;
    frequencies.forEach((cat, count) {
      if (count > maxCount) {
        maxCount = count;
        topCategory = cat;
      }
    });

    return SavedCalculationsSummary(
      totalCount: total,
      recentlyUsedCategories: recentCategories,
      categoryFrequencies: frequencies,
      mostFrequentCategory: topCategory,
      recentEntries: recent,
    );
  }
}
