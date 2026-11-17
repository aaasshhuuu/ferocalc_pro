import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fincalc_pro/core/security/secure_storage.dart';
import 'package:fincalc_pro/features/admin/data/models/admin_operational_metrics.dart';
import 'package:fincalc_pro/features/admin/data/models/admin_user_session.dart';
import 'package:fincalc_pro/features/admin/data/models/candidate_rate_diff.dart';
import 'package:fincalc_pro/features/admin/data/models/rate_audit_record.dart';
import 'package:fincalc_pro/features/admin/data/models/staged_candidate.dart';
import 'package:fincalc_pro/features/admin/data/services/admin_api_service.dart';
import 'package:fincalc_pro/features/admin/data/services/admin_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String createMockJwt({
  required String role,
  String email = 'admin@ferocalc.in',
  String userId = 'test-user-uuid',
  Duration validity = const Duration(hours: 2),
}) {
  const header = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
  final exp = (DateTime.now().add(validity).millisecondsSinceEpoch / 1000).round();
  final payloadMap = {
    'sub': userId,
    'email': email,
    'exp': exp,
    'app_metadata': {
      'ferocalc_role': role,
    },
  };
  final payloadBase64 = base64Url.encode(utf8.encode(jsonEncode(payloadMap))).replaceAll('=', '');
  return '$header.$payloadBase64.mock_signature';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Admin Models Parsing Tests', () {
    test('CandidateRateDiff parses correctly and sets diff type getters', () {
      final json = {
        'diffType': 'RATE_INCREASE',
        'previousVerifiedRate': 7.10,
        'rateDelta': 0.15,
        'details': 'Rate increased from 7.10% to 7.25%',
      };

      final diff = CandidateRateDiff.fromJson(json);
      expect(diff.diffType, 'RATE_INCREASE');
      expect(diff.previousVerifiedRate, 7.10);
      expect(diff.rateDelta, 0.15);
      expect(diff.details, 'Rate increased from 7.10% to 7.25%');
      expect(diff.isRateIncrease, isTrue);
      expect(diff.isNewRate, isFalse);
    });

    test('StagedCandidate parses DAYS domain candidate with diff and anomalies', () {
      final json = {
        'id': 'cand-uuid-1',
        'bankCode': 'HDFC',
        'sourceId': 'hdfc_retail_domestic',
        'productType': 'Retail Domestic FD',
        'customerType': 'REGULAR',
        'tenureDomain': 'DAYS',
        'displayTenure': '7 - 14 days',
        'minTenureDays': 7,
        'maxTenureDays': 14,
        'interestRate': 3.00,
        'seniorCitizenRate': 3.50,
        'minDeposit': 1000,
        'maxDeposit': 20000000,
        'isCallable': true,
        'effectiveFrom': '2026-08-19',
        'sourceUrl': 'https://www.hdfcbank.com/fd-rates',
        'validationStatus': 'VALID',
        'validationErrors': <String>[],
        'anomalyFlags': <String>[],
        'stagingStatus': 'IN_REVIEW',
        'diff': {
          'diffType': 'RATE_INCREASE',
          'previousVerifiedRate': 2.75,
          'rateDelta': 0.25,
        },
      };

      final candidate = StagedCandidate.fromJson(json);
      expect(candidate.id, 'cand-uuid-1');
      expect(candidate.bankCode, 'HDFC');
      expect(candidate.interestRate, 3.00);
      expect(candidate.seniorCitizenRate, 3.50);
      expect(candidate.isDaysDomain, isTrue);
      expect(candidate.isCalendarDomain, isFalse);
      expect(candidate.minTenureDays, 7);
      expect(candidate.maxTenureDays, 14);
      expect(candidate.stagingStatus, 'IN_REVIEW');
      expect(candidate.isInReview, isTrue);
      expect(candidate.isValid, isTrue);
      expect(candidate.diff?.diffType, 'RATE_INCREASE');
      expect(candidate.diff?.rateDelta, 0.25);
    });

    test('StagedCandidate parses CALENDAR domain candidate and snake_case fields', () {
      final json = {
        'id': 'cand-uuid-2',
        'bank_code': 'SBI',
        'product_type': 'Amrit Vrishti 444 Days',
        'customer_type': 'SENIOR_CITIZEN',
        'tenure_domain': 'CALENDAR',
        'display_tenure': '1 Year 2 Months 19 Days',
        'source_tenure_text': '444 Days (Amrit Vrishti)',
        'min_years': 1,
        'min_months': 2,
        'min_days_cal': 19,
        'min_operator': 'GTE',
        'max_years': 1,
        'max_months': 2,
        'max_days_cal': 19,
        'max_operator': 'LTE',
        'interest_rate': 7.75,
        'senior_citizen_rate': 7.75,
        'min_deposit': 5000,
        'max_deposit': 20000000,
        'is_callable': true,
        'effective_from': '2026-07-15',
        'source_url': 'https://sbi.co.in/rates',
        'validation_status': 'WARNING',
        'validation_errors': <String>[],
        'anomaly_flags': ['TENURE_SPECIAL_SCHEME_MATCH'],
        'staging_status': 'DRAFT',
      };

      final candidate = StagedCandidate.fromJson(json);
      expect(candidate.id, 'cand-uuid-2');
      expect(candidate.bankCode, 'SBI');
      expect(candidate.isCalendarDomain, isTrue);
      expect(candidate.minYears, 1);
      expect(candidate.minMonths, 2);
      expect(candidate.minDaysCal, 19);
      expect(candidate.interestRate, 7.75);
      expect(candidate.hasWarnings, isTrue);
      expect(candidate.isDraft, isTrue);
    });

    test('RateAuditRecord parses audit log fields correctly', () {
      final json = {
        'id': 'audit-1',
        'rate_id': 'rate-uuid-1',
        'action': 'PROMOTION',
        'old_value': {'status': 'IN_REVIEW'},
        'new_value': {'status': 'VERIFIED'},
        'performed_by': 'admin-uuid',
        'performed_at': '2026-11-12T10:00:00Z',
        'notes': 'Manual verified promotion approved',
      };

      final record = RateAuditRecord.fromJson(json);
      expect(record.id, 'audit-1');
      expect(record.rateId, 'rate-uuid-1');
      expect(record.action, 'PROMOTION');
      expect(record.performedBy, 'admin-uuid');
      expect(record.notes, 'Manual verified promotion approved');
    });

    test('AdminOperationalMetrics handles counts and honest unavailable state', () {
      const metrics = AdminOperationalMetrics(
        totalStaged: 42,
        draftCount: 10,
        inReviewCount: 15,
        promotedCount: 12,
        rejectedCount: 5,
        anomalyCount: 2,
      );

      expect(metrics.totalStaged, 42);
      expect(metrics.inReviewCount, 15);
      expect(metrics.isUnavailable, isFalse);

      final unavailable = AdminOperationalMetrics.unavailable('Supabase service unavailable');
      expect(unavailable.isUnavailable, isTrue);
      expect(unavailable.unavailableReason, contains('Supabase service unavailable'));
      expect(unavailable.totalStaged, isNull);
    });
  });

  group('AdminUserSession & Role Authorization Tests', () {
    test('AdminUserSession extracts ADMIN role from valid JWT', () {
      final token = createMockJwt(role: 'ADMIN', email: 'admin@ferocalc.in');
      final session = AdminUserSession.fromJwt(token);

      expect(session, isNotNull);
      expect(session!.role, 'ADMIN');
      expect(session.isAdmin, isTrue);
      expect(session.isReviewer, isFalse);
      expect(session.isAuthorized, isTrue);
      expect(session.isExpired, isFalse);
      expect(session.email, 'admin@ferocalc.in');
    });

    test('AdminUserSession extracts REVIEWER role from valid JWT', () {
      final token = createMockJwt(role: 'REVIEWER', email: 'reviewer@ferocalc.in');
      final session = AdminUserSession.fromJwt(token);

      expect(session, isNotNull);
      expect(session!.role, 'REVIEWER');
      expect(session.isAdmin, isFalse);
      expect(session.isReviewer, isTrue);
      expect(session.isAuthorized, isTrue);
    });

    test('AdminUserSession rejects unauthorized role (USER / AUDITOR)', () {
      final userToken = createMockJwt(role: 'USER');
      expect(AdminUserSession.fromJwt(userToken), isNull);

      final auditorToken = createMockJwt(role: 'AUDITOR');
      expect(AdminUserSession.fromJwt(auditorToken), isNull);
    });

    test('AdminUserSession rejects malformed or tampered tokens', () {
      expect(AdminUserSession.fromJwt('invalid-token'), isNull);
      expect(AdminUserSession.fromJwt('header.payload'), isNull);
      expect(AdminUserSession.fromJwt(''), isNull);
    });

    test('AdminUserSession detects expired tokens', () {
      final expiredToken = createMockJwt(
        role: 'ADMIN',
        validity: const Duration(seconds: -10),
      );
      final session = AdminUserSession.fromJwt(expiredToken);
      expect(session, isNotNull);
      expect(session!.isExpired, isTrue);
    });
  });

  group('AdminAuthService State & Persistence Tests', () {
    test('Initializes correctly and persists token to secure storage', () async {
      final storage = SecureStorage();
      final authService = AdminAuthService(secureStorage: storage);

      await authService.init();
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentSession, isNull);

      final token = createMockJwt(role: 'ADMIN', email: 'admin@ferocalc.in');
      await authService.loginWithToken(token);

      expect(authService.isAuthenticated, isTrue);
      expect(authService.isAdmin, isTrue);
      expect(authService.token, token);

      final storedToken = await storage.read(key: AdminAuthService.tokenStorageKey);
      expect(storedToken, token);
    });

    test('Logout clears storage and resets session', () async {
      final storage = SecureStorage();
      final authService = AdminAuthService(secureStorage: storage);
      final token = createMockJwt(role: 'REVIEWER');
      await authService.loginWithToken(token);

      expect(authService.isAuthenticated, isTrue);
      await authService.logout();

      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentSession, isNull);
      final stored = await storage.read(key: AdminAuthService.tokenStorageKey);
      expect(stored, isNull);
    });

    test('Rejects loginWithToken when role is not ADMIN or REVIEWER', () async {
      final storage = SecureStorage();
      final authService = AdminAuthService(secureStorage: storage);
      final userToken = createMockJwt(role: 'USER');

      expect(
        () => authService.loginWithToken(userToken),
        throwsA(isA<Exception>()),
      );
      expect(authService.isAuthenticated, isFalse);
    });
  });

  group('AdminApiService Contract & Safety Tests', () {
    test('Sets Authorization: Bearer token header on outbound requests', () async {
      final storage = SecureStorage();
      final authService = AdminAuthService(secureStorage: storage);
      final token = createMockJwt(role: 'ADMIN');
      await authService.loginWithToken(token);

      RequestOptions? capturedOptions;
      final apiService = AdminApiService(
        authService: authService,
        baseUrl: 'https://backend.example.com/api',
      );

      apiService.addInterceptorForTesting(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'status': 'ok', 'total': 0, 'candidates': <dynamic>[]},
              ),
            );
          },
        ),
      );

      await apiService.getStagedCandidates(limit: 5);

      expect(capturedOptions, isNotNull);
      expect(capturedOptions!.headers['Authorization'], 'Bearer $token');
      expect(capturedOptions!.queryParameters['limit'], 5);
    });

    test('Handles 401 response by automatically logging out session', () async {
      final storage = SecureStorage();
      final authService = AdminAuthService(secureStorage: storage);
      final token = createMockJwt(role: 'ADMIN');
      await authService.loginWithToken(token);
      expect(authService.isAuthenticated, isTrue);

      final apiService = AdminApiService(authService: authService);
      apiService.addInterceptorForTesting(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  data: {'status': 'error', 'message': 'Invalid or expired token'},
                ),
              ),
            );
          },
        ),
      );

      try {
        await apiService.getStagedCandidates();
      } catch (_) {}

      // Allow microtask in async onError to finish
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Expired token must result in logout
      expect(authService.isAuthenticated, isFalse);
    });

    test('Promote candidate formats payload and returns promoted rate info', () async {
      final storage = SecureStorage();
      final authService = AdminAuthService(secureStorage: storage);
      final token = createMockJwt(role: 'ADMIN');
      await authService.loginWithToken(token);

      RequestOptions? capturedOptions;
      final apiService = AdminApiService(authService: authService);
      apiService.addInterceptorForTesting(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'ok',
                  'promotedRate': {'id': 'rate-new-1', 'status': 'VERIFIED'},
                  'reason': 'Admin manual verification and promotion',
                },
              ),
            );
          },
        ),
      );

      final result = await apiService.promoteCandidate(
        candidateId: 'cand-123',
        notes: 'Verified against official published circular',
      );

      expect(result['status'], 'ok');
      expect(result['promotedRate']['id'], 'rate-new-1');
      expect(capturedOptions?.path, contains('staged-candidates/cand-123/promote'));
      final decodedBody = jsonDecode(capturedOptions?.data as String);
      expect(decodedBody['notes'], 'Verified against official published circular');
    });

    test('Reject candidate formats payload and propagates rejection message', () async {
      final storage = SecureStorage();
      final authService = AdminAuthService(secureStorage: storage);
      final token = createMockJwt(role: 'REVIEWER');
      await authService.loginWithToken(token);

      RequestOptions? capturedOptions;
      final apiService = AdminApiService(authService: authService);
      apiService.addInterceptorForTesting(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedOptions = options;
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'ok',
                  'message': 'Candidate rejected',
                  'id': 'cand-456',
                },
              ),
            );
          },
        ),
      );

      final result = await apiService.rejectCandidate(
        candidateId: 'cand-456',
        reason: 'Tenure bucket overlaps non-callable tier',
      );

      expect(result['status'], 'ok');
      expect(capturedOptions?.path, contains('staged-candidates/cand-456/reject'));
      final decodedBody = jsonDecode(capturedOptions?.data as String);
      expect(decodedBody['reason'], 'Tenure bucket overlaps non-callable tier');
    });

    test('getOperationalMetrics queries real counts across statuses without fabrication', () async {
      final storage = SecureStorage();
      final authService = AdminAuthService(secureStorage: storage);
      final token = createMockJwt(role: 'ADMIN');
      await authService.loginWithToken(token);

      final apiService = AdminApiService(authService: authService);
      apiService.addInterceptorForTesting(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final status = options.queryParameters['status'];
            final hasAnomalies = options.queryParameters['hasAnomalies'];

            int total = 100;
            if (status == 'DRAFT') total = 20;
            if (status == 'IN_REVIEW') total = 30;
            if (status == 'PROMOTED') total = 40;
            if (status == 'REJECTED') total = 10;
            if (hasAnomalies == 'true') total = 4;

            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'status': 'ok', 'total': total, 'candidates': <dynamic>[]},
              ),
            );
          },
        ),
      );

      final metrics = await apiService.getOperationalMetrics();

      expect(metrics.isUnavailable, isFalse);
      expect(metrics.totalStaged, 100);
      expect(metrics.draftCount, 20);
      expect(metrics.inReviewCount, 30);
      expect(metrics.promotedCount, 40);
      expect(metrics.rejectedCount, 10);
      expect(metrics.anomalyCount, 4);
    });
  });
}
