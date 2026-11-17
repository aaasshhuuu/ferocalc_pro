import 'package:dio/dio.dart';
import 'package:fincalc_pro/core/services/rate_data_source.dart';
import 'package:fincalc_pro/core/services/verified_rate_service.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  group('VerifiedRateService — URL Normalization & Construction', () {
    test('normalizeApiBaseUrl handles URLs already ending with /api', () {
      const url = 'https://backend.example.com/api';
      expect(VerifiedRateService.normalizeApiBaseUrl(url), 'https://backend.example.com/api');
    });

    test('normalizeApiBaseUrl trims trailing slash from /api/', () {
      const url = 'https://backend.example.com/api/';
      expect(VerifiedRateService.normalizeApiBaseUrl(url), 'https://backend.example.com/api');
    });

    test('normalizeApiBaseUrl appends /api to domain-only URLs', () {
      const url = 'https://backend.example.com';
      expect(VerifiedRateService.normalizeApiBaseUrl(url), 'https://backend.example.com/api');
    });

    test('normalizeApiBaseUrl handles domain with trailing slash without duplicating slash', () {
      const url = 'https://backend.example.com/';
      expect(VerifiedRateService.normalizeApiBaseUrl(url), 'https://backend.example.com/api');
    });

    test('normalizeApiBaseUrl trims whitespace and handles multiple trailing slashes', () {
      const url = '   https://backend.example.com///   ';
      expect(VerifiedRateService.normalizeApiBaseUrl(url), 'https://backend.example.com/api');
    });

    test('normalizeApiBaseUrl falls back to defaultBaseUrl for empty string', () {
      expect(
        VerifiedRateService.normalizeApiBaseUrl('   '),
        VerifiedRateService.defaultBaseUrl,
      );
    });

    test('normalizeApiBaseUrl handles staging Vercel URL accurately', () {
      const stagingUrl =
          'https://ferocalc-staging-backend-ovyehkz8j-kuldip12490-8771s-projects.vercel.app/api';
      expect(
        VerifiedRateService.normalizeApiBaseUrl(stagingUrl),
        'https://ferocalc-staging-backend-ovyehkz8j-kuldip12490-8771s-projects.vercel.app/api',
      );

      const stagingWithoutApi =
          'https://ferocalc-staging-backend-ovyehkz8j-kuldip12490-8771s-projects.vercel.app';
      expect(
        VerifiedRateService.normalizeApiBaseUrl(stagingWithoutApi),
        'https://ferocalc-staging-backend-ovyehkz8j-kuldip12490-8771s-projects.vercel.app/api',
      );
    });

    test('buildEndpointUrl constructs clean paths without double slashes', () {
      final urlWithSlash = VerifiedRateService.buildEndpointUrl(
        '/verified-rates/top',
        'https://staging.test.com/api',
      );
      expect(urlWithSlash, 'https://staging.test.com/api/verified-rates/top');

      final urlWithoutSlash = VerifiedRateService.buildEndpointUrl(
        'verified-rates/top',
        'https://staging.test.com/api',
      );
      expect(urlWithoutSlash, 'https://staging.test.com/api/verified-rates/top');

      final urlWithRawDomain = VerifiedRateService.buildEndpointUrl(
        'verified-rates/bank/bank-sbi',
        'https://staging.test.com/',
      );
      expect(urlWithRawDomain, 'https://staging.test.com/api/verified-rates/bank/bank-sbi');
    });
  });

  group('VerifiedRateService — Mock HTTP API & Error Handling', () {
    late Dio testDio;

    setUp(() {
      testDio = Dio();
      VerifiedRateService.setDioForTesting(testDio);
      VerifiedRateService.setBaseUrlForTesting('https://test-backend.com/api');
    });

    tearDown(() {
      VerifiedRateService.setDioForTesting(null);
      VerifiedRateService.setBaseUrlForTesting(null);
    });

    test('fetchAll: returns verified rates on successful 200 response', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          responseHandler: (options) {
            expect(options.path, 'https://test-backend.com/api/verified-rates');
            expect(options.queryParameters['customerType'], 'REGULAR');
            return Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'ok',
                'data': [
                  {
                    'id': 'rate-01',
                    'bank_id': 'bank-hdfc',
                    'bank_name': 'HDFC Bank',
                    'bank_short_name': 'HDFC',
                    'customer_type': 'REGULAR',
                    'min_tenure_days': 365,
                    'max_tenure_days': 730,
                    'min_deposit': 5000,
                    'interest_rate': 7.10,
                    'is_callable': true,
                    'compounding_frequency': 'QUARTERLY',
                    'effective_from': '2026-10-01T00:00:00Z',
                  },
                ],
                'meta': {
                  'source': 'verified',
                  'count': 1,
                },
              },
            );
          },
        ),
      );

      final response = await VerifiedRateService.fetchAll(customerType: 'REGULAR');

      expect(response.hasError, isFalse);
      expect(response.isVerifiedSource, isTrue);
      expect(response.rates.length, 1);
      expect(response.rates.first.interestRate, 7.10);
      expect(response.source, 'verified');
    });

    test('fetchAll: distinguishes 503 Supabase unconfigured from successful empty rates', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          errorHandler: (options) => DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 503,
              data: {
                'status': 'unavailable',
                'message': 'Verified rate database is not configured.',
              },
            ),
          ),
        ),
      );

      final response = await VerifiedRateService.fetchAll();

      expect(response.hasError, isTrue);
      expect(response.isVerifiedSource, isFalse);
      expect(response.statusCode, 503);
      expect(response.source, 'unavailable');
      expect(response.rates, isEmpty);
      expect(response.errorMessage, contains('database is not configured'));
    });

    test('fetchAll: marks 500 server error as error and does not assert verified source', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          errorHandler: (options) => DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 500,
              data: {
                'status': 'error',
                'message': 'Internal database query failure',
              },
            ),
          ),
        ),
      );

      final response = await VerifiedRateService.fetchAll();

      expect(response.hasError, isTrue);
      expect(response.isVerifiedSource, isFalse);
      expect(response.source, 'error');
      expect(response.statusCode, 500);
      expect(response.rates, isEmpty);
      expect(response.errorMessage, contains('Internal database query failure'));
    });

    test('fetchAll: marks connection failure as error', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          errorHandler: (options) => DioException(
            requestOptions: options,
            message: 'Connection refused',
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      final response = await VerifiedRateService.fetchAll();

      expect(response.hasError, isTrue);
      expect(response.isVerifiedSource, isFalse);
      expect(response.source, 'error');
      expect(response.rates, isEmpty);
      expect(response.errorMessage, contains('Could not reach'));
    });

    test('fetchTopVerified: parses rates on 200 response', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          responseHandler: (options) {
            expect(options.path, 'https://test-backend.com/api/verified-rates/top');
            expect(options.queryParameters['limit'], 5);
            return Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'ok',
                'data': [
                  {
                    'id': 'rate-top-1',
                    'bank_id': 'bank-au',
                    'bank_name': 'AU Small Finance Bank',
                    'bank_short_name': 'AU_SFB',
                    'customer_type': 'REGULAR',
                    'min_tenure_days': 365,
                    'max_tenure_days': 730,
                    'interest_rate': 7.75,
                    'is_callable': true,
                    'effective_from': '2026-10-01T00:00:00Z',
                  },
                ],
              },
            );
          },
        ),
      );

      final rates = await VerifiedRateService.fetchTopVerified(limit: 5);
      expect(rates.length, 1);
      expect(rates.first.interestRate, 7.75);
    });

    test('fetchTopVerified: rethrows connection error to enable caller graceful fallback', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          errorHandler: (options) => DioException(
            requestOptions: options,
            message: 'Network unreachable',
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      expect(
        () => VerifiedRateService.fetchTopVerified(limit: 5),
        throwsA(isA<DioException>()),
      );
    });

    test('fetchTopVerified: returns empty list honestly on 503 unconfigured backend', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          errorHandler: (options) => DioException(
            requestOptions: options,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 503,
              data: {'status': 'unavailable'},
            ),
          ),
        ),
      );

      final rates = await VerifiedRateService.fetchTopVerified(limit: 5);
      expect(rates, isEmpty);
    });

    test('isBackendAvailable: returns true for 200, false for error', () async {
      testDio.interceptors.add(
        MockDioInterceptor(
          responseHandler: (options) => Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
          ),
        ),
      );
      final available = await VerifiedRateService.isBackendAvailable();
      expect(available, isTrue);

      testDio.interceptors.clear();
      testDio.interceptors.add(
        MockDioInterceptor(
          errorHandler: (options) => DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          ),
        ),
      );
      final unavailable = await VerifiedRateService.isBackendAvailable();
      expect(unavailable, isFalse);
    });
  });

  group('RateDataSourceRegistry & VerifiedSupabaseRateDataSource', () {
    test('RateDataSourceRegistry produces normalized base URL ending with /api', () {
      final sources = RateDataSourceRegistry.all();
      expect(sources.length, 2);
      expect(sources[0], isA<VerifiedSupabaseRateDataSource>());
      expect(sources[1], isA<LegacyJsonRateDataSource>());

      final verifiedSource = sources[0] as VerifiedSupabaseRateDataSource;
      expect(verifiedSource.baseUrl, endsWith('/api'));
      expect(verifiedSource.isVerified, isTrue);
    });

    test('VerifiedSupabaseRateDataSource passes baseUrl to VerifiedRateService', () async {
      final testDio = Dio();
      VerifiedRateService.setDioForTesting(testDio);

      String? requestedPath;
      testDio.interceptors.add(
        MockDioInterceptor(
          responseHandler: (options) {
            requestedPath = options.path;
            return Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': 'ok',
                'data': <Map<String, dynamic>>[],
              },
            );
          },
        ),
      );

      const customSource = VerifiedSupabaseRateDataSource(
        baseUrl: 'https://staging.custom.domain/api',
      );

      await customSource.fetchTopVerifiedRates();
      expect(requestedPath, 'https://staging.custom.domain/api/verified-rates/top');

      await customSource.fetchAllVerifiedRates();
      expect(requestedPath, 'https://staging.custom.domain/api/verified-rates');

      await customSource.isAvailable();
      expect(requestedPath, 'https://staging.custom.domain/api/verified-rates/banks');

      VerifiedRateService.setDioForTesting(null);
    });
  });
}
