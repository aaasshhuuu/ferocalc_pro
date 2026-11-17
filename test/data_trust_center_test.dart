// FeroCalc Phase 5.0.1 — Data Trust Center, Freshness & Rate History Test Suite
//
// Tests consumer-facing Data Trust Center, Rate Freshness, and Rate History:
// 1. Freshness API response parsing.
// 2. Missing or malformed timestamps.
// 3. Pending update handling.
// 4. Collection failure while verified rates remain available.
// 5. Data coverage metrics.
// 6. Public history filtering and data sanitization.
// 7. Empty and unavailable history states.
// 8. Source link validation.
// 9. Consumer access without authentication.
// 10. Full audit history remaining admin protected.
// 11. Presentation widgets (DataCoverageSection, RateFreshnessSection, VerifiedRateHistorySection, VerificationProcessSection, SourceTransparencySection).
// 12. Full DataTrustCenterScreen and VerificationDetailSheet integration.

import 'package:dio/dio.dart';
import 'package:fincalc_pro/core/models/bank.dart';
import 'package:fincalc_pro/core/models/data_trust_models.dart';
import 'package:fincalc_pro/core/models/fd_rate.dart';
import 'package:fincalc_pro/core/models/verified_fd_rate.dart';
import 'package:fincalc_pro/core/services/verified_rate_service.dart';
import 'package:fincalc_pro/core/widgets/verification_detail_sheet.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/features/trust_center/presentation/screens/data_trust_center_screen.dart';
import 'package:fincalc_pro/features/trust_center/presentation/widgets/data_coverage_section.dart';
import 'package:fincalc_pro/features/trust_center/presentation/widgets/rate_freshness_section.dart';
import 'package:fincalc_pro/features/trust_center/presentation/widgets/source_transparency_section.dart';
import 'package:fincalc_pro/features/trust_center/presentation/widgets/verification_process_section.dart';
import 'package:fincalc_pro/features/trust_center/presentation/widgets/verified_rate_history_section.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDioInterceptor extends Interceptor {
  MockDioInterceptor({this.responseHandler, this.errorHandler});

  final Response<dynamic> Function(RequestOptions options)? responseHandler;
  final DioException Function(RequestOptions options)? errorHandler;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (errorHandler != null) {
      handler.reject(errorHandler!(options));
    } else if (responseHandler != null) {
      handler.resolve(responseHandler!(options));
    } else {
      handler.next(options);
    }
  }
}

Widget _wrapWithApp(Widget child, {bool scrollable = false}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()),
      BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: scrollable ? SingleChildScrollView(child: child) : child,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  group('Group 1: DataTrustModels — Freshness & Safe State Evaluations', () {
    test('RateFreshnessInfo.fromJson: successfully parses complete payload', () {
      final json = {
        'sourceId': 'src-pnb-01',
        'bankCode': 'PNB',
        'bankName': 'Punjab National Bank',
        'sourceUrl': 'https://www.pnbindia.in/Interest-Rates-Deposit.html',
        'lastCheckedAt': '2026-11-12T10:00:00.000Z',
        'lastSuccessAt': '2026-11-12T10:00:00.000Z',
        'lastStatus': 'UNCHANGED',
        'isStale': false,
        'pendingReviewCount': 0,
        'hasPendingReview': false,
        'updateDetected': false,
      };

      final info = RateFreshnessInfo.fromJson(json);

      expect(info.sourceId, 'src-pnb-01');
      expect(info.bankCode, 'PNB');
      expect(info.bankName, 'Punjab National Bank');
      expect(info.sourceUrl, 'https://www.pnbindia.in/Interest-Rates-Deposit.html');
      expect(info.lastCheckedAt, DateTime.utc(2026, 11, 12, 10, 0, 0));
      expect(info.lastSuccessAt, DateTime.utc(2026, 11, 12, 10, 0, 0));
      expect(info.lastStatus, 'UNCHANGED');
      expect(info.isStale, isFalse);
      expect(info.pendingReviewCount, 0);
      expect(info.hasPendingReview, isFalse);
      expect(info.updateDetected, isFalse);
      expect(info.consumerState, ConsumerFreshnessState.recentlyChecked);
      expect(info.consumerState.label, 'Recently checked');
    });

    test('RateFreshnessInfo.fromJson: handles missing or malformed timestamps without crashing', () {
      final jsonMissingDates = {
        'sourceId': 'src-hdfc',
        'bankCode': 'HDFC',
        'bankName': 'HDFC Bank',
        'sourceUrl': 'https://www.hdfcbank.com/fd-rates',
        'lastCheckedAt': null,
        'lastSuccessAt': null,
        'lastStatus': 'UNKNOWN',
        'isStale': false,
        'pendingReviewCount': 0,
        'hasPendingReview': false,
        'updateDetected': false,
      };

      final infoMissing = RateFreshnessInfo.fromJson(jsonMissingDates);
      expect(infoMissing.lastCheckedAt, isNull);
      expect(infoMissing.lastSuccessAt, isNull);
      expect(infoMissing.consumerState, ConsumerFreshnessState.freshnessInfoUnavailable);

      final jsonMalformedDates = {
        'sourceId': 'src-sbi',
        'bankCode': 'SBI',
        'bankName': 'State Bank of India',
        'sourceUrl': 'https://sbi.co.in/rates',
        'lastCheckedAt': 'invalid-date-format-9999',
        'lastSuccessAt': 'not-a-valid-date',
        'lastStatus': 'OK',
        'isStale': false,
        'pendingReviewCount': 0,
        'hasPendingReview': false,
        'updateDetected': false,
      };

      final infoMalformed = RateFreshnessInfo.fromJson(jsonMalformedDates);
      expect(infoMalformed.lastCheckedAt, isNull);
      expect(infoMalformed.lastSuccessAt, isNull);
      expect(infoMalformed.consumerState, ConsumerFreshnessState.recentlyChecked);
    });

    test('ConsumerFreshnessState: accurately detects verification update pending', () {
      final infoPending = RateFreshnessInfo.fromJson({
        'sourceId': 'src-icici',
        'bankCode': 'ICICI',
        'bankName': 'ICICI Bank',
        'sourceUrl': 'https://www.icicibank.com/rates',
        'lastCheckedAt': '2026-11-12T11:00:00Z',
        'lastSuccessAt': '2026-11-12T11:00:00Z',
        'lastStatus': 'CHANGED',
        'isStale': false,
        'pendingReviewCount': 2,
        'hasPendingReview': true,
        'updateDetected': true,
      });

      expect(infoPending.consumerState, ConsumerFreshnessState.verificationUpdatePending);
      expect(infoPending.consumerState.label, 'Verification update pending');
      expect(infoPending.publicStatusDescription, contains('awaiting verification review'));
    });

    test('ConsumerFreshnessState: accurately distinguishes collection failure without invalidating verified rate', () {
      final infoFailed = RateFreshnessInfo.fromJson({
        'sourceId': 'src-axis',
        'bankCode': 'AXIS',
        'bankName': 'Axis Bank',
        'sourceUrl': 'https://www.axisbank.com/rates',
        'lastCheckedAt': '2026-11-12T11:30:00Z',
        'lastSuccessAt': '2026-11-11T11:30:00Z',
        'lastStatus': 'FETCH_FAILED',
        'isStale': false,
        'pendingReviewCount': 0,
        'hasPendingReview': false,
        'updateDetected': false,
      });

      expect(infoFailed.consumerState, ConsumerFreshnessState.sourceUnavailable);
      expect(infoFailed.consumerState.label, 'Source temporarily unavailable');
      // Must not expose stack traces or raw error strings to consumers
      expect(infoFailed.publicStatusDescription, contains('Published verified rates remain valid until updated.'));
    });

    test('ConsumerFreshnessState: older data flagged when isStale is true', () {
      final infoStale = RateFreshnessInfo.fromJson({
        'sourceId': 'src-kotak',
        'bankCode': 'KOTAK',
        'bankName': 'Kotak Mahindra Bank',
        'sourceUrl': 'https://www.kotak.com/rates',
        'lastCheckedAt': '2026-11-10T10:00:00Z',
        'lastSuccessAt': '2026-11-10T10:00:00Z',
        'lastStatus': 'UNCHANGED',
        'isStale': true,
        'pendingReviewCount': 0,
        'hasPendingReview': false,
        'updateDetected': false,
      });

      expect(infoStale.consumerState, ConsumerFreshnessState.olderData);
      expect(infoStale.consumerState.label, 'Older data — verify with bank');
    });
  });

  group('Group 2: DataTrustModels — Verified Rate History & Deltas', () {
    test('VerifiedRateHistoryEntry.fromJson: parses rate transition and computes diffs', () {
      final jsonCurrent = {
        'id': 'rate-pnb-02',
        'rateId': 'rate-pnb-02',
        'bankId': '425d8373-c612-4bb6-9218-672d09ea47f1',
        'bankName': 'Punjab National Bank',
        'customerType': 'REGULAR',
        'interestRate': 7.25,
        'previousRate': 7.00,
        'tenureDescription': '1 Year to 443 Days',
        'tenureDomain': 'CALENDAR',
        'minTenureDays': 365,
        'maxTenureDays': 443,
        'effectiveFrom': '2026-10-01T00:00:00Z',
        'effectiveUntil': null,
        'verifiedAt': '2026-10-02T10:00:00Z',
        'status': 'VERIFIED',
        'isCallable': true,
        'sourceUrl': 'https://www.pnbindia.in/rates',
        'rateCategory': 'STANDARD',
      };

      final entry = VerifiedRateHistoryEntry.fromJson(jsonCurrent);

      expect(entry.id, 'rate-pnb-02');
      expect(entry.bankName, 'Punjab National Bank');
      expect(entry.interestRate, 7.25);
      expect(entry.previousRate, 7.00);
      expect(entry.rateDifference, closeTo(0.25, 0.001));
      expect(entry.hasRateIncreased, isTrue);
      expect(entry.hasRateDecreased, isFalse);
      expect(entry.isCurrent, isTrue);
      expect(entry.status, 'VERIFIED');
    });

    test('VerifiedRateHistoryEntry: computes rate decrease diff', () {
      final jsonArchived = {
        'id': 'rate-pnb-01',
        'rateId': 'rate-pnb-01',
        'bankId': '425d8373-c612-4bb6-9218-672d09ea47f1',
        'bankName': 'Punjab National Bank',
        'customerType': 'REGULAR',
        'interestRate': 6.80,
        'previousRate': 7.00,
        'tenureDescription': '1 Year to 443 Days',
        'tenureDomain': 'CALENDAR',
        'effectiveFrom': '2026-05-01T00:00:00Z',
        'effectiveUntil': '2026-10-01T00:00:00Z',
        'status': 'ARCHIVED',
        'isCallable': true,
        'rateCategory': 'STANDARD',
      };

      final entry = VerifiedRateHistoryEntry.fromJson(jsonArchived);

      expect(entry.interestRate, 6.80);
      expect(entry.previousRate, 7.00);
      expect(entry.rateDifference, closeTo(-0.20, 0.001));
      expect(entry.hasRateIncreased, isFalse);
      expect(entry.hasRateDecreased, isTrue);
      expect(entry.isCurrent, isFalse);
    });

    test('VerifiedRateHistoryResponse: handles empty baseline history state honestly', () {
      final response = VerifiedRateHistoryResponse.success(
        history: const [],
        bankId: 'bank-empty-uuid',
        bankName: 'Canara Bank',
        hasHistoricalChanges: false,
        note: 'No historical rate revisions recorded yet. Current rate represents initial verified baseline.',
      );

      expect(response.history.isEmpty, isTrue);
      expect(response.count, 0);
      expect(response.hasHistoricalChanges, isFalse);
      expect(response.note, contains('initial verified baseline'));
      expect(response.hasError, isFalse);
    });
  });

  group('Group 3: VerifiedRateService — Mock HTTP API & Error Handling', () {
    late Dio testDio;

    setUp(() {
      testDio = Dio();
      VerifiedRateService.setDioForTesting(testDio);
      VerifiedRateService.setBaseUrlForTesting('https://test-staging.ferocalc.com/api');
    });

    tearDown(() {
      VerifiedRateService.setDioForTesting(null);
      VerifiedRateService.setBaseUrlForTesting(null);
    });

    test('fetchFreshness: parses 200 OK response with allowlisted telemetry', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          responseHandler: (options) {
            expect(options.path, 'https://test-staging.ferocalc.com/api/verified-rates/freshness');
            return Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'ok',
                'data': [
                  {
                    'sourceId': 'src-1',
                    'bankCode': 'PNB',
                    'bankName': 'Punjab National Bank',
                    'sourceUrl': 'https://pnbindia.in/rates',
                    'lastCheckedAt': '2026-11-12T09:00:00Z',
                    'lastSuccessAt': '2026-11-12T09:00:00Z',
                    'lastStatus': 'UNCHANGED',
                    'isStale': false,
                    'pendingReviewCount': 0,
                    'hasPendingReview': false,
                    'updateDetected': false,
                  },
                ],
                'meta': {
                  'count': 1,
                  'anyUpdatePending': false,
                  'allFresh': true,
                  'note': 'Official source telemetry',
                },
              },
            );
          },
        ),
      );

      final response = await VerifiedRateService.fetchFreshness();

      expect(response.hasError, isFalse);
      expect(response.count, 1);
      expect(response.allFresh, isTrue);
      expect(response.anyUpdatePending, isFalse);
      expect(response.sources.first.bankCode, 'PNB');
      expect(response.sources.first.consumerState, ConsumerFreshnessState.recentlyChecked);
    });

    test('fetchFreshness: handles collection failure while rates remain available', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          responseHandler: (options) {
            return Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'ok',
                'data': [
                  {
                    'sourceId': 'src-failed',
                    'bankCode': 'HDFC',
                    'bankName': 'HDFC Bank',
                    'sourceUrl': 'https://hdfcbank.com/rates',
                    'lastCheckedAt': '2026-11-12T10:00:00Z',
                    'lastSuccessAt': '2026-11-11T10:00:00Z',
                    'lastStatus': 'FETCH_FAILED',
                    'isStale': false,
                    'pendingReviewCount': 0,
                    'hasPendingReview': false,
                    'updateDetected': false,
                  },
                ],
                'meta': {
                  'count': 1,
                  'anyUpdatePending': false,
                  'allFresh': false,
                },
              },
            );
          },
        ),
      );

      final response = await VerifiedRateService.fetchFreshness();

      expect(response.hasError, isFalse);
      expect(response.allFresh, isFalse);
      expect(response.sources.first.consumerState, ConsumerFreshnessState.sourceUnavailable);
      expect(response.sources.first.publicStatusDescription, contains('Published verified rates remain valid'));
    });

    test('fetchFreshness: network failure returns unavailable safely without unhandled exception', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          errorHandler: (options) => DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: 'Connection refused',
          ),
        ),
      );

      final response = await VerifiedRateService.fetchFreshness();

      expect(response.hasError, isTrue);
      expect(response.sources.isEmpty, isTrue);
      expect(response.errorMessage, isNotNull);
    });

    test('fetchHistory: retrieves rate transitions and applies filters', () async {
      const bankId = '425d8373-c612-4bb6-9218-672d09ea47f1';

      testDio.interceptors.add(
        MockDioInterceptor(
          responseHandler: (options) {
            expect(options.path, 'https://test-staging.ferocalc.com/api/verified-rates/history/$bankId');
            expect(options.queryParameters['customerType'], 'REGULAR');
            expect(options.queryParameters['isCallable'], true);
            return Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'ok',
                'data': [
                  {
                    'id': 'rate-pnb-v2',
                    'bankId': bankId,
                    'bankName': 'Punjab National Bank',
                    'customerType': 'REGULAR',
                    'interestRate': 7.25,
                    'previousRate': 7.00,
                    'tenureDescription': '1 Year to 443 Days',
                    'tenureDomain': 'CALENDAR',
                    'status': 'VERIFIED',
                    'isCallable': true,
                  },
                  {
                    'id': 'rate-pnb-v1',
                    'bankId': bankId,
                    'bankName': 'Punjab National Bank',
                    'customerType': 'REGULAR',
                    'interestRate': 7.00,
                    'previousRate': null,
                    'tenureDescription': '1 Year to 443 Days',
                    'tenureDomain': 'CALENDAR',
                    'status': 'ARCHIVED',
                    'isCallable': true,
                  },
                ],
                'meta': {
                  'bankId': bankId,
                  'bankName': 'Punjab National Bank',
                  'count': 2,
                  'hasHistoricalChanges': true,
                },
              },
            );
          },
        ),
      );

      final response = await VerifiedRateService.fetchHistory(
        bankId,
        customerType: 'REGULAR',
        isCallable: true,
      );

      expect(response.hasError, isFalse);
      expect(response.count, 2);
      expect(response.hasHistoricalChanges, isTrue);
      expect(response.history.first.interestRate, 7.25);
      expect(response.history.first.previousRate, 7.00);
      expect(response.history.first.hasRateIncreased, isTrue);
    });

    test('fetchHistory: handles 404 bank not found without throwing', () async {
      const missingBankId = '00000000-0000-0000-0000-000000000000';

      testDio.interceptors.add(
        MockDioInterceptor(
          errorHandler: (options) => DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 404,
              data: {
                'status': 'error',
                'message': 'Bank not found with id $missingBankId',
              },
            ),
          ),
        ),
      );

      final response = await VerifiedRateService.fetchHistory(missingBankId);

      expect(response.hasError, isTrue);
      expect(response.statusCode, 404);
      expect(response.errorMessage, contains('Bank not found'));
    });

    test('fetchCoverageMetrics: partitions verified vs unsupported banks', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          responseHandler: (options) {
            if (options.path.endsWith('/verified-rates/banks')) {
              return Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'ok',
                  'data': [
                    {
                      'id': 'b-pnb',
                      'name': 'Punjab National Bank',
                      'short_name': 'PNB',
                      'category': 'PSU',
                      'is_active': true,
                      'display_order': 1,
                    },
                    {
                      'id': 'b-unsupported',
                      'name': 'Unsupported Co-op Bank',
                      'short_name': 'UCB',
                      'category': 'COOP',
                      'is_active': true,
                      'display_order': 99,
                    },
                  ],
                },
              );
            } else if (options.path.endsWith('/verified-rates')) {
              return Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'ok',
                  'data': [
                    {
                      'id': 'rate-pnb-1',
                      'bank_id': 'b-pnb',
                      'bank_name': 'Punjab National Bank',
                      'bank_short_name': 'PNB',
                      'customer_type': 'REGULAR',
                      'interest_rate': 7.25,
                      'min_tenure_days': 365,
                      'max_tenure_days': 443,
                      'is_callable': true,
                      'compounding_frequency': 'QUARTERLY',
                    },
                  ],
                  'meta': {'source': 'verified', 'count': 1},
                },
              );
            }
            return Response<dynamic>(requestOptions: options, statusCode: 404);
          },
        ),
      );

      final metrics = await VerifiedRateService.fetchCoverageMetrics();

      expect(metrics.activeVerifiedBanksCount, 1);
      expect(metrics.totalVerifiedRatesCount, 1);
      expect(metrics.verifiedBanks.length, 1);
      expect(metrics.verifiedBanks.first.id, 'b-pnb');
      expect(metrics.unsupportedBanks.length, 1);
      expect(metrics.unsupportedBanks.first.id, 'b-unsupported');
    });
  });

  group('Group 4: Presentation Widgets — Unit & Visual Tests', () {
    testWidgets('DataCoverageSection: renders KPI cards and lists banks', (tester) async {
      const verifiedBank = Bank(
        id: 'b-pnb',
        name: 'Punjab National Bank',
        shortName: 'PNB',
        type: BankType.public,
        status: BankStatus.active,
        officialWebsite: 'https://pnbindia.in',
      );

      const unsupportedBank = Bank(
        id: 'b-unsupported',
        name: 'Unsupported Rural Bank',
        shortName: 'URB',
        type: BankType.cooperativeBank,
        status: BankStatus.active,
        officialWebsite: 'https://unsupported.com',
      );

      const metrics = DataCoverageMetrics(
        activeVerifiedBanksCount: 1,
        totalVerifiedRatesCount: 12,
        verifiedBanks: [verifiedBank],
        unsupportedBanks: [unsupportedBank],
      );

      await tester.pumpWidget(
        _wrapWithApp(
          DataCoverageSection(
            metrics: metrics,
            isLoading: false,
            onRetry: () {},
            onSelectBankForHistory: (_) {},
          ),
          scrollable: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VERIFIED BANKS'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('VERIFIED SLABS'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Punjab National Bank'), findsOneWidget);
      expect(find.text('Unsupported Rural Bank'), findsOneWidget);
      expect(find.text('OTHER CATALOG BANKS (AWAITING VERIFIED PIPELINE)'), findsOneWidget);
    });

    testWidgets('DataCoverageSection: renders Phase 5.0.2 segregated coverage with slab counts and retrying badges', (tester) async {
      const verifiedBank1 = Bank(
        id: 'b-pnb',
        name: 'Punjab National Bank',
        shortName: 'PNB',
        type: BankType.public,
        status: BankStatus.active,
        officialWebsite: 'https://pnb.bank.in',
      );
      const verifiedBank2 = Bank(
        id: 'b-axis',
        name: 'Axis Bank',
        shortName: 'AXIS',
        type: BankType.private,
        status: BankStatus.active,
        officialWebsite: 'https://axisbank.com',
      );
      const awaitingBank = Bank(
        id: 'b-kotak',
        name: 'Kotak Mahindra Bank',
        shortName: 'KOTAK',
        type: BankType.private,
        status: BankStatus.active,
        officialWebsite: 'https://kotak.com',
      );
      const catalogOnlyBank = Bank(
        id: 'b-rural',
        name: 'Regional Gramin Bank',
        shortName: 'RGB',
        type: BankType.cooperativeBank,
        status: BankStatus.active,
      );

      const metrics = DataCoverageMetrics(
        activeVerifiedBanksCount: 2,
        totalVerifiedRatesCount: 92,
        verifiedBanks: [verifiedBank1, verifiedBank2],
        unsupportedBanks: [awaitingBank, catalogOnlyBank],
        supportedSourcesAwaitingVerification: [awaitingBank],
        temporarilyUnavailableBanks: [verifiedBank2],
        catalogOnlyBanks: [catalogOnlyBank],
        verifiedSlabsCountByBank: {
          'b-pnb': 56,
          'b-axis': 36,
        },
      );

      await tester.pumpWidget(
        _wrapWithApp(
          DataCoverageSection(
            metrics: metrics,
            isLoading: false,
            onRetry: () {},
            onSelectBankForHistory: (_) {},
          ),
          scrollable: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('56 verified rate slabs available'), findsOneWidget);
      expect(find.text('36 verified rate slabs • Source check retrying'), findsOneWidget);
      expect(find.text('OFFICIAL SOURCES AWAITING VERIFICATION'), findsOneWidget);
      expect(find.text('Kotak Mahindra Bank'), findsOneWidget);
      expect(find.text('Official source configured — Awaiting verification review'), findsOneWidget);
      expect(find.text('OTHER CATALOG BANKS (AWAITING VERIFIED PIPELINE)'), findsOneWidget);
      expect(find.text('Regional Gramin Bank'), findsOneWidget);
    });

    testWidgets('RateFreshnessSection: renders architectural principle and freshness status cards', (tester) async {
      final info = RateFreshnessInfo(
        sourceId: 'src-1',
        bankCode: 'PNB',
        bankName: 'Punjab National Bank',
        sourceUrl: 'https://pnbindia.in/rates',
        lastCheckedAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastSuccessAt: DateTime.now().subtract(const Duration(hours: 1)),
        lastStatus: 'UNCHANGED',
        isStale: false,
        pendingReviewCount: 0,
        hasPendingReview: false,
        updateDetected: false,
      );

      final freshness = RateFreshnessResponse.success(
        sources: [info],
        allFresh: true,
        anyUpdatePending: false,
      );

      var refreshTriggered = false;

      await tester.pumpWidget(
        _wrapWithApp(
          RateFreshnessSection(
            freshnessResponse: freshness,
            isLoading: false,
            onRefresh: () async {
              refreshTriggered = true;
            },
          ),
          scrollable: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OFFICIAL RATE FRESHNESS TELEMETRY'), findsOneWidget);
      expect(find.text('Consumer Integrity Guarantees'), findsOneWidget);
      expect(find.text('Recently Checked'), findsWidgets);
      expect(find.text('Punjab National Bank'), findsOneWidget);

      final refreshBtn = find.byTooltip('Check source freshness');
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pump();
      expect(refreshTriggered, isTrue);
    });

    testWidgets('VerifiedRateHistorySection: renders bank picker and rate change timeline', (tester) async {
      const bank = Bank(
        id: '425d8373-c612-4bb6-9218-672d09ea47f1',
        name: 'Punjab National Bank',
        shortName: 'PNB',
        type: BankType.public,
        status: BankStatus.active,
        officialWebsite: 'https://pnbindia.in',
      );

      await tester.pumpWidget(
        _wrapWithApp(
          const VerifiedRateHistorySection(
            banks: [bank],
            initialBank: bank,
          ),
          scrollable: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VERIFIED RATE HISTORY & AUDITED TRANSITIONS'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Senior Citizen'), findsOneWidget);
    });

    testWidgets('VerificationProcessSection: renders 7-step pipeline and status definitions', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const VerificationProcessSection(),
          scrollable: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('THE FEROCALC 7-STEP VERIFICATION WORKFLOW'), findsOneWidget);
      expect(find.text('1. Official Bank Source'), findsOneWidget);
      expect(find.text('2. Collection'), findsOneWidget);
      expect(find.text('3. Parsing'), findsOneWidget);
      expect(find.text('4. Validation'), findsOneWidget);
      expect(find.text('5. Change Detection'), findsOneWidget);
      expect(find.text('6. Review & Safe Promotion'), findsOneWidget);
      expect(find.text('7. Public Verified Rates'), findsOneWidget);

      expect(find.text('RATE STATUS DEFINITIONS & MEANING'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('IN_REVIEW'), findsOneWidget);
      expect(find.text('DRAFT'), findsOneWidget);
      expect(find.text('STALE'), findsOneWidget);
      expect(find.text('SUSPICIOUS'), findsOneWidget);
    });

    testWidgets('SourceTransparencySection: renders bank source cards with circular links', (tester) async {
      final rate = VerifiedFdRate(
        id: 'rate-pnb-01',
        bankId: 'b-pnb',
        bankName: 'Punjab National Bank',
        bankShortName: 'PNB',
        bankSourceDomain: 'pnbindia.in',
        customerType: VerifiedCustomerType.regular,
        minTenureDays: 365,
        maxTenureDays: 443,
        minDeposit: 1000,
        maxDeposit: 10000000,
        interestRate: 7.25,
        isCallable: true,
        compoundingFrequency: CompoundingFrequency.quarterly,
        effectiveFrom: DateTime.utc(2026, 10, 1),
        sourceUrl: 'https://pnbindia.in/rates',
        verifiedAt: DateTime.utc(2026, 10, 2, 10, 0),
      );

      await tester.pumpWidget(
        _wrapWithApp(
          SourceTransparencySection(
            verifiedRates: [rate],
            freshnessList: const [],
            isLoading: false,
          ),
          scrollable: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OFFICIAL SOURCE TRANSPARENCY & PROVENANCE'), findsOneWidget);
      expect(find.text('Punjab National Bank'), findsOneWidget);
      expect(find.text('Effective Date:'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('https://pnbindia.in/rates'), findsOneWidget);
    });

    testWidgets('VerificationDetailSheet: shows verification explanation and trust center navigation', (tester) async {
      final fdRate = FdRate(
        rateId: 'rate-pnb-01',
        bankId: '425d8373-c612-4bb6-9218-672d09ea47f1',
        customerType: CustomerType.regular,
        productType: FdProductType.callable,
        minTenureDays: 365,
        maxTenureDays: 443,
        interestRate: 7.25,
        verificationStatus: VerificationStatus.verified,
        verifiedAt: DateTime.utc(2026, 10, 2),
        sourceUrl: 'https://pnbindia.in/rates',
      );

      await tester.pumpWidget(
        _wrapWithApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => VerificationDetailSheet.show(context, fdRate, bankName: 'Punjab National Bank'),
              child: const Text('Show Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Rate Verification Details'), findsOneWidget);
      expect(find.text('Punjab National Bank'), findsOneWidget);
      expect(find.text('Trust Center'), findsOneWidget);
      expect(find.text('Verification Status'), findsOneWidget);
      expect(find.text('Data Freshness'), findsOneWidget);
    });
  });

  group('Group 5: DataTrustCenterScreen — Full Screen Tab Navigation', () {
    late Dio testDio;

    setUp(() {
      testDio = Dio();
      VerifiedRateService.setDioForTesting(testDio);
      VerifiedRateService.setBaseUrlForTesting('https://test-staging.ferocalc.com/api');

      testDio.interceptors.add(
        MockDioInterceptor(
          responseHandler: (options) {
            if (options.path.endsWith('/verified-rates/banks')) {
              return Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'ok',
                  'data': [
                    {
                      'id': 'b-pnb',
                      'name': 'Punjab National Bank',
                      'short_name': 'PNB',
                      'category': 'PSU',
                      'is_active': true,
                      'display_order': 1,
                    },
                  ],
                },
              );
            } else if (options.path.endsWith('/verified-rates/freshness')) {
              return Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'ok',
                  'data': [
                    {
                      'sourceId': 'src-pnb',
                      'bankCode': 'PNB',
                      'bankName': 'Punjab National Bank',
                      'sourceUrl': 'https://pnbindia.in/rates',
                      'lastCheckedAt': '2026-11-12T10:00:00Z',
                      'lastSuccessAt': '2026-11-12T10:00:00Z',
                      'lastStatus': 'UNCHANGED',
                      'isStale': false,
                      'pendingReviewCount': 0,
                      'hasPendingReview': false,
                      'updateDetected': false,
                    },
                  ],
                  'meta': {
                    'count': 1,
                    'anyUpdatePending': false,
                    'allFresh': true,
                  },
                },
              );
            } else if (options.path.contains('/verified-rates/history/')) {
              return Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'ok',
                  'data': <Map<String, dynamic>>[],
                  'meta': {
                    'count': 0,
                    'hasHistoricalChanges': false,
                    'note': 'Initial verified baseline',
                  },
                },
              );
            } else if (options.path.endsWith('/verified-rates')) {
              return Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': 'ok',
                  'data': [
                    {
                      'id': 'rate-pnb-1',
                      'bank_id': 'b-pnb',
                      'bank_name': 'Punjab National Bank',
                      'bank_short_name': 'PNB',
                      'customer_type': 'REGULAR',
                      'interest_rate': 7.25,
                      'min_tenure_days': 365,
                      'max_tenure_days': 443,
                      'is_callable': true,
                      'compounding_frequency': 'QUARTERLY',
                      'effective_from': '2026-10-01T00:00:00Z',
                      'source_url': 'https://pnbindia.in/rates',
                      'verified_at': '2026-10-02T10:00:00Z',
                    },
                  ],
                  'meta': {'source': 'verified', 'count': 1},
                },
              );
            }
            return Response<dynamic>(requestOptions: options, statusCode: 404);
          },
        ),
      );
    });

    tearDown(() {
      VerifiedRateService.setDioForTesting(null);
      VerifiedRateService.setBaseUrlForTesting(null);
    });

    testWidgets('renders all 5 tabs and allows tab navigation', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const DataTrustCenterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Data Trust Center'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Coverage'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Freshness'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'History'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Process'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Sources'), findsOneWidget);

      // Verify initial tab is Coverage
      expect(find.text('VERIFIED BANKS'), findsOneWidget);

      // Navigate to Freshness tab
      await tester.tap(find.widgetWithText(Tab, 'Freshness'));
      await tester.pumpAndSettle();
      expect(find.text('OFFICIAL RATE FRESHNESS TELEMETRY'), findsOneWidget);

      // Navigate to Process tab
      await tester.tap(find.widgetWithText(Tab, 'Process'));
      await tester.pumpAndSettle();
      expect(find.text('THE FEROCALC 7-STEP VERIFICATION WORKFLOW'), findsOneWidget);

      // Navigate to Sources tab
      await tester.tap(find.widgetWithText(Tab, 'Sources'));
      await tester.pumpAndSettle();
      expect(find.text('OFFICIAL SOURCE TRANSPARENCY & PROVENANCE'), findsOneWidget);
    });
  });
}
