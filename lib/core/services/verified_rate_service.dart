/// FeroCalc Verified FD Rate Engine — HTTP service layer
/// Performs actual HTTP calls to the FeroCalc backend verified-rate API.
/// Supabase credentials are NEVER used in Flutter Web.
/// All Supabase access is proxied through the Node.js backend.

import 'package:dio/dio.dart';
import '../models/verified_fd_rate.dart';

class VerifiedRateService {
  static const String _defaultBaseUrl = 'https://backend-ten-livid-14.vercel.app/api';
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  // ============================================================
  // Public queries — uses /api/verified-rates (server-proxied)
  // ============================================================

  /// Fetch top-ranked verified rates.
  /// Returns empty list if Supabase is not configured on the backend.
  static Future<List<VerifiedFdRate>> fetchTopVerified({
    int? tenureDays,
    String customerType = 'REGULAR',
    int limit = 10,
  }) async {
    try {
      final params = <String, dynamic>{
        'limit': limit,
        'customerType': customerType,
        if (tenureDays != null) 'tenureDays': tenureDays,
      };

      final response = await _dio.get('$_baseUrl/verified-rates/top', queryParameters: params);

      if (response.statusCode == 503) {
        // Supabase not configured — honest empty state
        return [];
      }

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List?) ?? [];
        return list
            .map((j) => VerifiedFdRate.fromJson(j as Map<String, dynamic>))
            .toList();
      }

      return [];
    } on DioException {
      // Network failure — caller handles gracefully
      return [];
    }
  }

  /// Fetch all verified rates with optional filters.
  static Future<VerifiedRatesResponse> fetchAll({
    String? customerType,
    int? tenureDays,
    double? depositAmount,
    String? bankId,
  }) async {
    try {
      final params = <String, dynamic>{
        if (customerType != null) 'customerType': customerType,
        if (tenureDays != null) 'tenureDays': tenureDays,
        if (depositAmount != null) 'depositAmount': depositAmount,
        if (bankId != null) 'bankId': bankId,
      };

      final response = await _dio.get('$_baseUrl/verified-rates', queryParameters: params);
      final data = response.data as Map<String, dynamic>;

      if (response.statusCode == 503) {
        return VerifiedRatesResponse(
          rates: [],
          source: 'verified',
          note: 'Verified rate database is not yet configured.',
          fetchedAt: DateTime.now(),
        );
      }

      final list = (data['data'] as List?) ?? [];
      return VerifiedRatesResponse(
        rates: list.map((j) => VerifiedFdRate.fromJson(j as Map<String, dynamic>)).toList(),
        source: data['meta']?['source']?.toString() ?? 'verified',
        note: data['meta']?['note']?.toString(),
        fetchedAt: DateTime.now(),
      );
    } on DioException {
      return VerifiedRatesResponse(
        rates: [],
        source: 'verified',
        note: 'Could not reach the verified rate service.',
        fetchedAt: DateTime.now(),
      );
    }
  }

  /// Fetch verified rates for a specific bank.
  static Future<VerifiedRatesResponse> fetchByBank(String bankId, {String? customerType}) async {
    try {
      final params = <String, dynamic>{
        if (customerType != null) 'customerType': customerType,
      };

      final response = await _dio.get(
        '$_baseUrl/verified-rates/bank/$bankId',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['data'] as List?) ?? [];

      return VerifiedRatesResponse(
        rates: list.map((j) => VerifiedFdRate.fromJson(j as Map<String, dynamic>)).toList(),
        source: 'verified',
        fetchedAt: DateTime.now(),
      );
    } on DioException {
      return VerifiedRatesResponse(
        rates: [],
        source: 'verified',
        note: 'Could not reach the verified rate service.',
        fetchedAt: DateTime.now(),
      );
    }
  }

  /// Quick check — is the verified rate backend reachable?
  static Future<bool> isBackendAvailable() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/verified-rates/banks',
        options: Options(receiveTimeout: const Duration(seconds: 3)),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
