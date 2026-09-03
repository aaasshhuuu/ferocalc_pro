/// FeroCalc Verified FD Rate Engine
/// Abstract data source interface — Phase J
///
/// The app NEVER mixes verified and unverified data in a single list.
/// Each data source is consumed separately and labelled distinctly in UI.

import '../data/bank_data.dart';
import '../models/verified_fd_rate.dart';
import 'verified_rate_service.dart';

// ============================================================
// Abstract contract
// ============================================================

abstract class RateDataSource {
  /// Whether this source provides human-verified data.
  bool get isVerified;

  /// Fetch top-ranked rates for display on the home screen.
  /// [customerType] defaults to REGULAR if null.
  Future<List<VerifiedFdRate>> fetchTopVerifiedRates({
    int? tenureDays,
    String? customerType,
    int limit,
  });

  /// Fetch all rates, optionally filtered.
  Future<VerifiedRatesResponse> fetchAllVerifiedRates({
    String? customerType,
    int? tenureDays,
    double? depositAmount,
    String? bankId,
  });

  /// Whether this source is currently available (e.g., network/DB reachable).
  Future<bool> isAvailable();
}

// ============================================================
// VerifiedSupabaseRateDataSource
// Fetches from /api/verified-rates on the FeroCalc backend,
// which in turn queries the Supabase verified_fd_rates view.
//
// Supabase credentials are NEVER used in Flutter directly.
// All Supabase access is server-proxied via the Node backend.
// ============================================================

class VerifiedSupabaseRateDataSource implements RateDataSource {
  final String baseUrl;

  // Internal Dio import kept minimal — use the existing ApiClient
  const VerifiedSupabaseRateDataSource({required this.baseUrl});

  @override
  bool get isVerified => true;

  @override
  Future<bool> isAvailable() async {
    return VerifiedRateService.isBackendAvailable();
  }

  @override
  Future<List<VerifiedFdRate>> fetchTopVerifiedRates({
    int? tenureDays,
    String? customerType,
    int limit = 10,
  }) async {
    // Delegates to the concrete HTTP service.
    // VerifiedRateService handles Dio calls and graceful error fallback.
    return VerifiedRateService.fetchTopVerified(
      tenureDays: tenureDays,
      customerType: customerType ?? 'REGULAR',
      limit: limit,
    );
  }

  @override
  Future<VerifiedRatesResponse> fetchAllVerifiedRates({
    String? customerType,
    int? tenureDays,
    double? depositAmount,
    String? bankId,
  }) async {
    return VerifiedRateService.fetchAll(
      customerType: customerType,
      tenureDays: tenureDays,
      depositAmount: depositAmount,
      bankId: bankId,
    );
  }
}

// ============================================================
// LegacyJsonRateDataSource
// Wraps the existing BankDataService / BankRateApiService.
// Returns rates labeled as UNVERIFIED / PENDING_REVIEW.
// Never presented to users as verified.
// ============================================================

class LegacyJsonRateDataSource implements RateDataSource {
  const LegacyJsonRateDataSource();

  @override
  bool get isVerified => false;

  @override
  Future<bool> isAvailable() async => true; // always available (local data)

  @override
  Future<List<VerifiedFdRate>> fetchTopVerifiedRates({
    int? tenureDays,
    String? customerType,
    int limit = 10,
  }) async {
    // Legacy source does not produce VerifiedFdRate objects.
    // Return empty — caller will fall back to legacy BankInfo display.
    return [];
  }

  @override
  Future<VerifiedRatesResponse> fetchAllVerifiedRates({
    String? customerType,
    int? tenureDays,
    double? depositAmount,
    String? bankId,
  }) async {
    return VerifiedRatesResponse(
      rates: [],
      source: 'legacy_unverified',
      note: 'No verified rates available. Showing unverified reference data only.',
      fetchedAt: DateTime.now(),
    );
  }

  /// Access to the underlying legacy bank list (for backward-compat display).
  List<BankInfo> getLegacyBanks() => BankDataService.getAllBanks();
}

// ============================================================
// RateDataSourceRegistry
// Single place to resolve which source to use.
// Usage:
//   final source = await RateDataSourceRegistry.resolve();
// ============================================================

class RateDataSourceRegistry {
  static const _defaultBaseUrl = 'https://backend-ten-livid-14.vercel.app';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  /// Returns a list of available sources in priority order:
  ///   [0] VerifiedSupabaseRateDataSource (if configured + reachable)
  ///   [1] LegacyJsonRateDataSource       (always available)
  ///
  /// Callers must use the sources SEPARATELY and label data accordingly.
  static List<RateDataSource> all() {
    final baseUrl = _configuredBaseUrl.replaceAll('/api', '');
    return [
      VerifiedSupabaseRateDataSource(baseUrl: baseUrl),
      const LegacyJsonRateDataSource(),
    ];
  }

  static LegacyJsonRateDataSource legacy() => const LegacyJsonRateDataSource();
}
