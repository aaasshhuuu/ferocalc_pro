import '../models/financial_profile.dart';

abstract class FinancialProfileRepository {
  /// Loads the persisted financial profile from local device storage.
  /// Returns [FinancialProfile.empty] if no profile is configured.
  Future<FinancialProfile> getProfile();

  /// Saves the user's financial profile strictly to local device storage.
  /// Never uploads to Supabase or public networks.
  Future<void> saveProfile(FinancialProfile profile);

  /// Clears only the local financial profile without affecting financial goals,
  /// calculation history, or favorite banks.
  Future<void> clearProfile();
}
