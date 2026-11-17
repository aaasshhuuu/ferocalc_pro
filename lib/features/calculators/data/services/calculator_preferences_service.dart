import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/calculator_metadata.dart';

/// Service managing locally persisted calculator favorites and launch history.
class CalculatorPreferencesService extends ChangeNotifier {

  CalculatorPreferencesService({
    required this.preferences,
    int maxRecentEntries = defaultMaxRecentEntries,
  }) : _maxRecentEntries = maxRecentEntries;
  static const String favoritesStorageKey = 'ferocalc_favorite_calculator_ids';
  static const String recentsStorageKey = 'ferocalc_recent_calculator_ids';
  static const int defaultMaxRecentEntries = 10;

  final SharedPreferences preferences;
  final int _maxRecentEntries;

  // ═══════════════════════════════════════════════════════════════════════════
  // FAVORITES MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns the unmodifiable list of unique favorite calculator IDs.
  List<String> getFavoriteIds() {
    final rawList = preferences.getStringList(favoritesStorageKey) ?? [];
    // Filter to valid registered IDs and maintain uniqueness
    final validSet = <String>{};
    for (final id in rawList) {
      if (CalculatorRegistry.findById(id) != null) {
        validSet.add(id);
      }
    }
    return List.unmodifiable(validSet.toList());
  }

  /// Whether a calculator ID is marked as favorite.
  bool isFavorite(String id) {
    return getFavoriteIds().contains(id);
  }

  /// Toggles favorite status for a calculator.
  Future<bool> toggleFavorite(String id) async {
    if (CalculatorRegistry.findById(id) == null) return false;

    final currentFavorites = getFavoriteIds().toList();
    if (currentFavorites.contains(id)) {
      currentFavorites.remove(id);
    } else {
      currentFavorites.add(id);
    }

    final success = await preferences.setStringList(favoritesStorageKey, currentFavorites);
    notifyListeners();
    return success;
  }

  /// Adds a calculator ID to favorites, preventing duplicates.
  Future<bool> addFavorite(String id) async {
    if (CalculatorRegistry.findById(id) == null) return false;

    final currentFavorites = getFavoriteIds().toList();
    if (currentFavorites.contains(id)) return true;

    currentFavorites.add(id);
    final success = await preferences.setStringList(favoritesStorageKey, currentFavorites);
    notifyListeners();
    return success;
  }

  /// Removes a calculator ID from favorites.
  Future<bool> removeFavorite(String id) async {
    final currentFavorites = getFavoriteIds().toList();
    if (!currentFavorites.contains(id)) return true;

    currentFavorites.remove(id);
    final success = await preferences.setStringList(favoritesStorageKey, currentFavorites);
    notifyListeners();
    return success;
  }

  /// Returns the list of favorite CalculatorMeta objects.
  List<CalculatorMeta> getFavorites() {
    final ids = getFavoriteIds();
    final List<CalculatorMeta> result = [];
    for (final id in ids) {
      final meta = CalculatorRegistry.findById(id);
      if (meta != null) {
        result.add(meta);
      }
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECENTLY USED CALCULATORS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns the unmodifiable list of recently launched calculator IDs (most recent first).
  List<String> getRecentIds() {
    final rawList = preferences.getStringList(recentsStorageKey) ?? [];
    final List<String> validList = [];
    final seen = <String>{};

    for (final id in rawList) {
      if (!seen.contains(id) && CalculatorRegistry.findById(id) != null) {
        seen.add(id);
        validList.add(id);
      }
    }

    return List.unmodifiable(validList);
  }

  /// Records a calculator launch. Moves to top, prevents duplicates, caps at limit.
  Future<bool> recordLaunch(String id) async {
    if (CalculatorRegistry.findById(id) == null) return false;

    final currentRecents = getRecentIds().toList();
    // Remove if already present so it can be moved to the top
    currentRecents.remove(id);
    currentRecents.insert(0, id);

    // Limit to maxRecentEntries
    if (currentRecents.length > _maxRecentEntries) {
      currentRecents.removeRange(_maxRecentEntries, currentRecents.length);
    }

    final success = await preferences.setStringList(recentsStorageKey, currentRecents);
    notifyListeners();
    return success;
  }

  /// Clears recently used calculator history.
  Future<bool> clearRecent() async {
    final success = await preferences.setStringList(recentsStorageKey, []);
    notifyListeners();
    return success;
  }

  /// Returns the list of recently launched CalculatorMeta objects (most recent first).
  List<CalculatorMeta> getRecentCalculators() {
    final ids = getRecentIds();
    final List<CalculatorMeta> result = [];
    for (final id in ids) {
      final meta = CalculatorRegistry.findById(id);
      if (meta != null) {
        result.add(meta);
      }
    }
    return result;
  }
}
