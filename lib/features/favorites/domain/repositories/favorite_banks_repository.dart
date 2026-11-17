import '../models/favorite_bank.dart';

abstract class FavoriteBanksRepository {
  /// Retrieves all saved favorite banks.
  Future<List<FavoriteBank>> getFavorites();

  /// Retrieves the set of saved favorite bank IDs.
  Future<Set<String>> getFavoriteIds();

  /// Checks if a specific bank ID is currently favorited.
  Future<bool> isFavorite(String bankId);

  /// Adds a bank to favorites. Returns true if newly added, false if already present.
  Future<bool> addFavorite(FavoriteBank bank);

  /// Removes a bank from favorites by ID. Returns true if removed.
  Future<bool> removeFavorite(String bankId);

  /// Toggles favorite status. Returns true if added, false if removed.
  Future<bool> toggleFavorite(FavoriteBank bank);

  /// Clears all favorites.
  Future<void> clearAllFavorites();
}
