/// FeroCalc Verified FD Rate Engine — HTTP service layer
/// Performs actual HTTP calls to the FeroCalc backend verified-rate API.
/// Supabase credentials are NEVER used in Flutter Web or mobile apps.
/// All Supabase access is proxied through the Node.js backend.

import 'package:dio/dio.dart';
import '../models/bank.dart';
import '../models/data_trust_models.dart';
import '../models/verified_fd_rate.dart';

class VerifiedRateService {
  static const String defaultBaseUrl = 'https://backend-ten-livid-14.vercel.app/api';

  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  static String _baseUrl = normalizeApiBaseUrl(_envBaseUrl);

  static Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ),);

  /// Current normalized base URL.
  static String get baseUrl => _baseUrl;

  /// Normalizes any raw base URL:
  /// - Falls back to [defaultBaseUrl] if empty or whitespace.
  /// - Trims leading/trailing whitespace.
  /// - Strips trailing slashes.
  /// - Ensures `/api` suffix is present once without duplication.
  static String normalizeApiBaseUrl(String rawUrl) {
    var trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      trimmed = defaultBaseUrl;
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (!trimmed.endsWith('/api')) {
      trimmed = '$trimmed/api';
    }
    return trimmed;
  }

  /// Constructs a normalized full endpoint URL given an endpoint path and optional custom base URL.
  static String buildEndpointUrl(String endpoint, [String? customBaseUrl]) {
    final base = customBaseUrl != null && customBaseUrl.trim().isNotEmpty
        ? normalizeApiBaseUrl(customBaseUrl)
        : _baseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return '$base$cleanEndpoint';
  }

  /// Sets custom Dio client for unit tests. Pass null to reset.
  static void setDioForTesting(Dio? dio) {
    if (dio != null) {
      _dio = dio;
    } else {
      _dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),);
    }
  }

  /// Sets custom base URL for testing. Pass null to reset to environment default.
  static void setBaseUrlForTesting(String? url) {
    _baseUrl = normalizeApiBaseUrl(url ?? _envBaseUrl);
  }

  // ============================================================
  // Public queries — uses /api/verified-rates (server-proxied)
  // ============================================================

  /// Fetch top-ranked verified rates.
  /// Supports either [tenureDays] (DAYS domain) or [years], [months], [daysCal] (CALENDAR domain).
  /// Returns empty list if Supabase is not configured on the backend (503).
  /// Rethrows on connection / server failures so callers can distinguish empty
  /// results from backend network failures.
  static Future<List<VerifiedFdRate>> fetchTopVerified({
    int? tenureDays,
    int? years,
    int? months,
    int? daysCal,
    String customerType = 'REGULAR',
    int limit = 10,
    bool? isCallable = true,
    String? baseUrl,
  }) async {
    final url = buildEndpointUrl('verified-rates/top', baseUrl);
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'customerType': customerType,
        if (tenureDays != null) 'tenureDays': tenureDays,
        if (years != null) 'years': years,
        if (months != null) 'months': months,
        if (daysCal != null) 'daysCal': daysCal,
        if (isCallable != null) 'isCallable': isCallable,
      };

      final response = await _dio.get<dynamic>(url, queryParameters: params);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List?) ?? [];
        return list
            .map((j) => VerifiedFdRate.fromJson(j as Map<String, dynamic>))
            .toList();
      }

      if (response.statusCode == 503) {
        // Supabase not configured — honest empty state
        return [];
      }

      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 503) {
        return [];
      }
      rethrow;
    }
  }

  /// Fetch all verified rates with optional filters.
  /// Supports either [tenureDays] (DAYS domain) or [years], [months], [daysCal] (CALENDAR domain).
  /// On backend error or network failure, returns a [VerifiedRatesResponse] with [hasError]=true
  /// instead of falsely asserting successful verified rates.
  static Future<VerifiedRatesResponse> fetchAll({
    String? customerType,
    int? tenureDays,
    int? years,
    int? months,
    int? daysCal,
    double? depositAmount,
    String? bankId,
    bool? isCallable = true,
    String? baseUrl,
  }) async {
    final url = buildEndpointUrl('verified-rates', baseUrl);
    try {
      final params = <String, dynamic>{
        if (customerType != null) 'customerType': customerType,
        if (tenureDays != null) 'tenureDays': tenureDays,
        if (years != null) 'years': years,
        if (months != null) 'months': months,
        if (daysCal != null) 'daysCal': daysCal,
        if (depositAmount != null) 'depositAmount': depositAmount,
        if (bankId != null) 'bankId': bankId,
        if (isCallable != null) 'isCallable': isCallable,
      };

      final response = await _dio.get<dynamic>(url, queryParameters: params);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 'ok' || data['data'] is List) {
          final list = (data['data'] as List?) ?? [];
          return VerifiedRatesResponse.success(
            rates: list.map((j) => VerifiedFdRate.fromJson(j as Map<String, dynamic>)).toList(),
            source: data['meta']?['source']?.toString() ?? 'verified',
            note: data['meta']?['note']?.toString(),
          );
        } else {
          return VerifiedRatesResponse.error(
            message: data['message']?.toString() ?? 'Backend returned unexpected format',
            statusCode: response.statusCode,
          );
        }
      }

      if (response.statusCode == 503) {
        return VerifiedRatesResponse.unavailable(
          message: 'Verified rate database is not yet configured.',
        );
      }

      return VerifiedRatesResponse.error(
        message: 'Unexpected server response: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 503) {
        final msg = e.response?.data is Map
            ? (e.response!.data as Map)['message']?.toString()
            : null;
        return VerifiedRatesResponse.unavailable(
          message: msg ?? 'Verified rate database is not yet configured.',
        );
      }
      final statusCode = e.response?.statusCode;
      final serverMsg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      return VerifiedRatesResponse.error(
        message: serverMsg ?? 'Could not reach the verified rate service.',
        statusCode: statusCode,
      );
    } catch (e) {
      return VerifiedRatesResponse.error(
        message: 'Failed to fetch verified rates: $e',
      );
    }
  }

  /// Fetch verified rates for a specific bank.
  static Future<VerifiedRatesResponse> fetchByBank(
    String bankId, {
    String? customerType,
    bool? isCallable = true,
    String? baseUrl,
  }) async {
    final url = buildEndpointUrl('verified-rates/bank/$bankId', baseUrl);
    try {
      final params = <String, dynamic>{
        if (customerType != null) 'customerType': customerType,
        if (isCallable != null) 'isCallable': isCallable,
      };

      final response = await _dio.get<dynamic>(
        url,
        queryParameters: params,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['status'] == 'ok' || data['data'] is List) {
          final list = (data['data'] as List?) ?? [];
          return VerifiedRatesResponse.success(
            rates: list.map((j) => VerifiedFdRate.fromJson(j as Map<String, dynamic>)).toList(),
            source: data['meta']?['source']?.toString() ?? 'verified',
            note: data['meta']?['note']?.toString(),
          );
        } else {
          return VerifiedRatesResponse.error(
            message: data['message']?.toString() ?? 'Backend returned unexpected format',
            statusCode: response.statusCode,
          );
        }
      }

      if (response.statusCode == 503) {
        return VerifiedRatesResponse.unavailable(
          message: 'Verified rate database is not yet configured.',
        );
      }

      return VerifiedRatesResponse.error(
        message: 'Unexpected server response: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 503) {
        final msg = e.response?.data is Map
            ? (e.response!.data as Map)['message']?.toString()
            : null;
        return VerifiedRatesResponse.unavailable(
          message: msg ?? 'Verified rate database is not yet configured.',
        );
      }
      final statusCode = e.response?.statusCode;
      final serverMsg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      return VerifiedRatesResponse.error(
        message: serverMsg ?? 'Could not reach the verified rate service.',
        statusCode: statusCode,
      );
    } catch (e) {
      return VerifiedRatesResponse.error(
        message: 'Failed to fetch verified rates for bank $bankId: $e',
      );
    }
  }

  /// Quick check — is the verified rate backend reachable?
  static Future<bool> isBackendAvailable({String? baseUrl}) async {
    try {
      final url = buildEndpointUrl('verified-rates/banks', baseUrl);
      final response = await _dio.get<dynamic>(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // Freshness & Transparency — uses /api/verified-rates/freshness
  // ============================================================

  /// Fetch rate source freshness telemetry.
  /// Strictly contains allowlisted public metadata without internal credentials or errors.
  static Future<RateFreshnessResponse> fetchFreshness({String? baseUrl}) async {
    final url = buildEndpointUrl('verified-rates/freshness', baseUrl);
    try {
      final response = await _dio.get<dynamic>(url);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List?) ?? [];
        final meta = data['meta'] as Map<String, dynamic>?;

        final sources = list
            .map((j) => RateFreshnessInfo.fromJson(j as Map<String, dynamic>))
            .toList();

        return RateFreshnessResponse.success(
          sources: sources,
          anyUpdatePending: meta?['anyUpdatePending'] == true,
          allFresh: meta?['allFresh'] == true,
          note: meta?['note']?.toString(),
        );
      }

      if (response.statusCode == 503) {
        return RateFreshnessResponse.unavailable(
          message: 'Rate freshness service is temporarily unavailable.',
        );
      }

      return RateFreshnessResponse.error(
        message: 'Unexpected server response: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 503) {
        return RateFreshnessResponse.unavailable(
          message: 'Rate freshness service is temporarily unavailable.',
        );
      }
      final serverMsg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      return RateFreshnessResponse.error(
        message: serverMsg ?? e.message ?? 'Could not retrieve rate freshness.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return RateFreshnessResponse.error(
        message: 'Failed to fetch rate freshness: $e',
      );
    }
  }

  // ============================================================
  // Pilot Bank Registry — uses /api/verified-rates/banks
  // ============================================================

  /// Fetch the list of active banks from the verified rates registry.
  static Future<List<Bank>> fetchBanks({String? baseUrl}) async {
    final url = buildEndpointUrl('verified-rates/banks', baseUrl);
    try {
      final response = await _dio.get<dynamic>(url);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List?) ?? [];
        return list.map((j) {
          final map = j as Map<String, dynamic>;
          return Bank(
            id: map['id']?.toString() ?? '',
            name: map['name']?.toString() ?? '',
            shortName: map['short_name']?.toString() ?? map['name']?.toString() ?? '',
            type: BankType.private,
            status: BankStatus.active,
            officialWebsite: map['official_website']?.toString(),
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // Verified Rate History — uses /api/verified-rates/history/:bankId
  // ============================================================

  /// Fetch published rate transition history for a bank.
  /// Only contains published VERIFIED and ARCHIVED rate changes.
  static Future<VerifiedRateHistoryResponse> fetchHistory(
    String bankId, {
    String? customerType,
    bool? isCallable,
    String? baseUrl,
  }) async {
    final url = buildEndpointUrl('verified-rates/history/$bankId', baseUrl);
    try {
      final params = <String, dynamic>{
        if (customerType != null) 'customerType': customerType,
        if (isCallable != null) 'isCallable': isCallable,
      };

      final response = await _dio.get<dynamic>(url, queryParameters: params);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List?) ?? [];
        final meta = data['meta'] as Map<String, dynamic>?;

        final history = list
            .map((j) => VerifiedRateHistoryEntry.fromJson(j as Map<String, dynamic>))
            .toList();

        return VerifiedRateHistoryResponse.success(
          history: history,
          bankId: meta?['bankId']?.toString() ?? bankId,
          bankName: meta?['bankName']?.toString(),
          hasHistoricalChanges: meta?['hasHistoricalChanges'] == true,
          note: meta?['note']?.toString(),
        );
      }

      if (response.statusCode == 503) {
        return VerifiedRateHistoryResponse.error(
          message: 'Rate history service is temporarily unavailable.',
          statusCode: 503,
        );
      }

      return VerifiedRateHistoryResponse.error(
        message: 'Unexpected server response: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      final serverMsg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      return VerifiedRateHistoryResponse.error(
        message: serverMsg ?? e.message ?? 'Could not retrieve rate history.',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return VerifiedRateHistoryResponse.error(
        message: 'Failed to fetch rate history: $e',
      );
    }
  }

  // ============================================================
  // Data Coverage Metrics Aggregator
  // ============================================================

  /// Computes accurate coverage metrics from actual API responses.
  /// Strictly adheres to zero fabrication of counts.
  static Future<DataCoverageMetrics> fetchCoverageMetrics({
    String? baseUrl,
    List<RateFreshnessInfo>? freshnessList,
  }) async {
    final banks = await fetchBanks(baseUrl: baseUrl);
    final ratesRes = await fetchAll(baseUrl: baseUrl, isCallable: null);

    final verifiedSlabsCountByBank = <String, int>{};
    for (final rate in ratesRes.rates) {
      verifiedSlabsCountByBank[rate.bankId] =
          (verifiedSlabsCountByBank[rate.bankId] ?? 0) + 1;
    }

    final verifiedBankIds = verifiedSlabsCountByBank.keys.toSet();

    // Fetch freshness telemetry if available for source health / awaiting review
    RateFreshnessResponse? freshnessRes;
    try {
      freshnessRes = await fetchFreshness(baseUrl: baseUrl);
    } catch (_) {
      // Graceful fallback
    }
    final freshness = freshnessList ?? freshnessRes?.sources ?? const [];

    final verifiedBanks = <Bank>[];
    final unsupportedBanks = <Bank>[];
    final supportedSourcesAwaitingVerification = <Bank>[];
    final temporarilyUnavailableBanks = <Bank>[];
    final catalogOnlyBanks = <Bank>[];

    final configuredSourceCodes = freshness.map((f) => f.bankCode.toUpperCase()).toSet();
    final unavailableCodes = freshness
        .where((f) => f.lastStatus == 'FETCH_FAILED' || f.consumerState == ConsumerFreshnessState.sourceUnavailable)
        .map((f) => f.bankCode.toUpperCase())
        .toSet();

    for (final bank in banks) {
      final code = bank.shortName.toUpperCase();
      final hasVerifiedSlabs = verifiedBankIds.contains(bank.id);

      if (hasVerifiedSlabs) {
        verifiedBanks.add(bank);
        if (unavailableCodes.contains(code)) {
          temporarilyUnavailableBanks.add(bank);
        }
      } else {
        unsupportedBanks.add(bank);
        if (configuredSourceCodes.contains(code)) {
          supportedSourcesAwaitingVerification.add(bank);
        } else {
          catalogOnlyBanks.add(bank);
        }
      }
    }

    return DataCoverageMetrics(
      activeVerifiedBanksCount: verifiedBanks.length,
      totalVerifiedRatesCount: ratesRes.rates.length,
      verifiedBanks: verifiedBanks,
      unsupportedBanks: unsupportedBanks,
      supportedSourcesAwaitingVerification: supportedSourcesAwaitingVerification,
      temporarilyUnavailableBanks: temporarilyUnavailableBanks,
      catalogOnlyBanks: catalogOnlyBanks,
      verifiedSlabsCountByBank: verifiedSlabsCountByBank,
    );
  }
}
