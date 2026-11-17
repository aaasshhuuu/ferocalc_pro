import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/favorite_bank.dart';
import '../../domain/repositories/favorite_banks_repository.dart';

class FavoriteBanksRepositoryImpl implements FavoriteBanksRepository {
  FavoriteBanksRepositoryImpl({required SharedPreferences preferences})
      : _preferences = preferences;

  static const String _kStorageKey = 'ferocalc_favorite_banks_v1';
  final SharedPreferences _preferences;

  @override
  Future<List<FavoriteBank>> getFavorites() async {
    final rawJson = _preferences.getString(_kStorageKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final list = <FavoriteBank>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            try {
              final bank = FavoriteBank.fromJson(item);
              if (bank.bankId.isNotEmpty) {
                list.add(bank);
              }
            } catch (_) {
              // Gracefully ignore corrupt entries
            }
          }
        }
        return list;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Set<String>> getFavoriteIds() async {
    final favorites = await getFavorites();
    return favorites.map((e) => e.bankId).toSet();
  }

  @override
  Future<bool> isFavorite(String bankId) async {
    final ids = await getFavoriteIds();
    return ids.contains(bankId);
  }

  @override
  Future<bool> addFavorite(FavoriteBank bank) async {
    if (bank.bankId.isEmpty) return false;

    final current = await getFavorites();
    // Prevent duplicate entries
    final existingIndex = current.indexWhere((e) => e.bankId == bank.bankId);
    if (existingIndex >= 0) {
      return false; // Already present
    }

    final updated = List<FavoriteBank>.from(current)..insert(0, bank);
    await _save(updated);
    return true;
  }

  @override
  Future<bool> removeFavorite(String bankId) async {
    final current = await getFavorites();
    final initialLength = current.length;
    current.removeWhere((e) => e.bankId == bankId);

    if (current.length != initialLength) {
      await _save(current);
      return true;
    }
    return false;
  }

  @override
  Future<bool> toggleFavorite(FavoriteBank bank) async {
    final current = await getFavorites();
    final existingIndex = current.indexWhere((e) => e.bankId == bank.bankId);

    if (existingIndex >= 0) {
      current.removeAt(existingIndex);
      await _save(current);
      return false; // Removed
    } else {
      current.insert(0, bank);
      await _save(current);
      return true; // Added
    }
  }

  @override
  Future<void> clearAllFavorites() async {
    await _preferences.remove(_kStorageKey);
  }

  Future<void> _save(List<FavoriteBank> list) async {
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await _preferences.setString(_kStorageKey, encoded);
  }
}
