import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/financial_profile.dart';
import '../../domain/repositories/financial_profile_repository.dart';
import '../models/financial_profile_model.dart';

class FinancialProfileRepositoryImpl implements FinancialProfileRepository {
  FinancialProfileRepositoryImpl({required this.preferences});

  static const String storageKey = 'ferocalc_financial_profile_v1';
  final SharedPreferences preferences;

  @override
  Future<FinancialProfile> getProfile() async {
    try {
      final raw = preferences.getString(storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return FinancialProfile.empty;
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return FinancialProfileModel.fromJson(decoded);
    } catch (_) {
      // In case of any corrupt local JSON, fallback gracefully to empty profile
      return FinancialProfile.empty;
    }
  }

  @override
  Future<void> saveProfile(FinancialProfile profile) async {
    final profileWithTimestamp = profile.copyWith(
      updatedAt: DateTime.now(),
    );
    final jsonMap = FinancialProfileModel.toJson(profileWithTimestamp);
    await preferences.setString(storageKey, jsonEncode(jsonMap));
  }

  @override
  Future<void> clearProfile() async {
    // Only remove profile storage key; do NOT clear other keys (goals, history, favorites)
    await preferences.remove(storageKey);
  }
}
