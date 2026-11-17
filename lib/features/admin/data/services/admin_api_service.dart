import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/services/verified_rate_service.dart';
import '../models/admin_operational_metrics.dart';
import '../models/rate_audit_record.dart';
import '../models/staged_candidate.dart';
import 'admin_auth_service.dart';

/// Response container for paginated staged candidates query.
class StagedCandidatesResponse {
  const StagedCandidatesResponse({
    required this.total,
    required this.limit,
    required this.offset,
    required this.candidates,
  });

  final int total;
  final int limit;
  final int offset;
  final List<StagedCandidate> candidates;
}

/// Service performing HTTP API requests to the FeroCalc Admin backend.
/// Uses server-side role validation via Bearer token.
class AdminApiService {
  AdminApiService({
    required this.authService,
    Dio? dio,
    String? baseUrl,
  }) : _baseUrl = baseUrl != null
            ? VerifiedRateService.normalizeApiBaseUrl(baseUrl)
            : VerifiedRateService.baseUrl {
    _dio = dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = authService.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          _handleDioError(e);
          return handler.next(e);
        },
      ),
    );
  }

  final AdminAuthService authService;
  late final Dio _dio;
  String _baseUrl;

  String get baseUrl => _baseUrl;

  void _handleDioError(DioException e) {
    if (e.response?.statusCode == 401) {
      // Token expired or invalid on server — clear local session
      authService.logout();
    }
  }

  void setBaseUrlForTesting(String url) {
    _baseUrl = VerifiedRateService.normalizeApiBaseUrl(url);
  }

  void setDioForTesting(Dio dio) {
    _dio = dio;
  }

  void addInterceptorForTesting(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  String _buildUrl(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$_baseUrl/admin$cleanPath';
  }

  /// Fetch operational metrics from actual backend counts.
  /// Does not fabricate counts. Returns unavailable state if backend is down.
  Future<AdminOperationalMetrics> getOperationalMetrics() async {
    try {
      // Query totals across statuses using limit=1 to read exact counts
      final totalFuture = _fetchCount(null);
      final draftFuture = _fetchCount('DRAFT');
      final inReviewFuture = _fetchCount('IN_REVIEW');
      final promotedFuture = _fetchCount('PROMOTED');
      final rejectedFuture = _fetchCount('REJECTED');
      final anomalyFuture = _fetchAnomalyCount();

      final results = await Future.wait([
        totalFuture,
        draftFuture,
        inReviewFuture,
        promotedFuture,
        rejectedFuture,
        anomalyFuture,
      ]);

      return AdminOperationalMetrics(
        totalStaged: results[0],
        draftCount: results[1],
        inReviewCount: results[2],
        promotedCount: results[3],
        rejectedCount: results[4],
        anomalyCount: results[5],
        lastRefreshedAt: DateTime.now(),
      );
    } catch (e) {
      return AdminOperationalMetrics.unavailable(
        'Backend metrics currently unavailable: ${e.toString()}',
      );
    }
  }

  Future<int> _fetchCount(String? status) async {
    try {
      final queryParams = <String, dynamic>{'limit': 1};
      if (status != null) {
        queryParams['status'] = status;
      }

      final response = await _dio.get<Map<String, dynamic>>(
        _buildUrl('staged-candidates'),
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final total = response.data!['total'];
        if (total is num) return total.toInt();
      }
      return 0;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<int> _fetchAnomalyCount() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _buildUrl('staged-candidates'),
        queryParameters: {'hasAnomalies': 'true', 'limit': 1},
      );

      if (response.statusCode == 200 && response.data != null) {
        final total = response.data!['total'];
        if (total is num) return total.toInt();
      }
      return 0;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Fetch staged candidates queue with filtering and pagination.
  Future<StagedCandidatesResponse> getStagedCandidates({
    String? status,
    String? bankCode,
    bool? hasAnomalies,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
        if (status != null && status.isNotEmpty && status != 'ALL') 'status': status,
        if (bankCode != null && bankCode.trim().isNotEmpty) 'bankCode': bankCode.trim().toUpperCase(),
        if (hasAnomalies != null) 'hasAnomalies': hasAnomalies.toString(),
      };

      final response = await _dio.get<Map<String, dynamic>>(
        _buildUrl('staged-candidates'),
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final total = (response.data!['total'] as num?)?.toInt() ?? 0;
        final rawCandidates = response.data!['candidates'] as List? ?? [];
        final candidates = rawCandidates
            .whereType<Map<String, dynamic>>()
            .map((c) => StagedCandidate.fromJson(c))
            .toList();

        return StagedCandidatesResponse(
          total: total,
          limit: limit,
          offset: offset,
          candidates: candidates,
        );
      }

      throw Exception('Failed to load staged candidates (status: ${response.statusCode})');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Promote a candidate to VERIFIED status.
  /// Requires ADMIN role (server strictly rejects REVIEWER with 403).
  Future<Map<String, dynamic>> promoteCandidate({
    required String candidateId,
    String? notes,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _buildUrl('staged-candidates/$candidateId/promote'),
        data: jsonEncode({
          'notes': notes ?? 'Admin manual verification and promotion',
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }
      throw Exception('Unexpected response: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      final message = e.response?.data?['message']?.toString() ?? e.message ?? 'Promotion failed';
      throw Exception(message);
    }
  }

  /// Reject a candidate.
  /// Available to both ADMIN and REVIEWER.
  Future<Map<String, dynamic>> rejectCandidate({
    required String candidateId,
    required String reason,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _buildUrl('staged-candidates/$candidateId/reject'),
        data: jsonEncode({
          'reason': reason.trim(),
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }
      throw Exception('Unexpected response: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      final message = e.response?.data?['message']?.toString() ?? e.message ?? 'Rejection failed';
      throw Exception(message);
    }
  }

  /// Fetch rate audit log from `GET /api/admin/rates/:id/audit`.
  Future<List<RateAuditRecord>> getRateAuditLog(String rateId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _buildUrl('rates/$rateId/audit'),
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data!['data'] as List? ?? [];
        return rawData
            .whereType<Map<String, dynamic>>()
            .map((r) => RateAuditRecord.fromJson(r))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception(e.response?.data?['message']?.toString() ?? e.message ?? 'Failed to fetch audit log');
    }
  }

  /// Fetch rates from `GET /api/admin/rates` filtered by status.
  Future<List<Map<String, dynamic>>> getVerifiedRates({String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status.toUpperCase();
      }

      final response = await _dio.get<Map<String, dynamic>>(
        _buildUrl('rates'),
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final list = response.data!['data'] as List? ?? [];
        return list.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } on DioException catch (e) {
      _handleDioError(e);
      throw Exception(e.response?.data?['message']?.toString() ?? e.message ?? 'Failed to fetch rates');
    }
  }

  /// Roll back a rate from `POST /api/admin/rates/:id/rollback`.
  Future<Map<String, dynamic>> rollbackRate({
    required String rateId,
    String? notes,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _buildUrl('rates/$rateId/rollback'),
        data: jsonEncode({
          'notes': notes ?? 'Administrative rollback via review console',
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!;
      }
      throw Exception('Unexpected response: ${response.statusCode}');
    } on DioException catch (e) {
      _handleDioError(e);
      final message = e.response?.data?['message']?.toString() ?? e.message ?? 'Rollback failed';
      throw Exception(message);
    }
  }
}
