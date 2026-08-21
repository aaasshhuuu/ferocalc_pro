import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bank_data.dart';

class BankRateResponse {
  final String lastUpdated;
  final String updateFrequency;
  final List<BankInfo> banks;

  BankRateResponse({
    required this.lastUpdated,
    required this.updateFrequency,
    required this.banks,
  });

  factory BankRateResponse.fromJson(Map<String, dynamic> json) {
    var banksList = json['banks'] as List? ?? [];
    List<BankInfo> banks = banksList.map((b) {
      return BankInfo(
        name: b['name'] ?? '',
        type: b['type'] ?? '',
        country: b['country'] ?? 'India',
        fdRates: Map<String, double>.from((b['fd_rates'] ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
        rdRates: Map<String, double>.from((b['rd_rates'] ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
        savingsRate: b['savings_rate']?.toDouble(),
        lastUpdated: json['last_updated'] ?? 'August 2026',
        shortName: b['short_name'] ?? '',
        established: b['established'] ?? '',
        headquarters: b['headquarters'] ?? '',
        totalBranches: b['total_branches'] ?? '',
        website: b['website'] ?? '',
        customerCare: b['customer_care'] ?? '',
        seniorCitizenExtra: (b['senior_citizen_extra'] ?? 0.50).toDouble(),
        offers: List<String>.from(b['offers'] ?? []),
        minFdAmount: b['min_fd_amount'] ?? 1000,
        maxFdTenure: b['max_fd_tenure'] ?? '10 years',
        features: List<String>.from(b['features'] ?? []),
      );
    }).toList();

    return BankRateResponse(
      lastUpdated: json['last_updated'] ?? '',
      updateFrequency: json['update_frequency'] ?? 'daily',
      banks: banks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'last_updated': lastUpdated,
      'update_frequency': updateFrequency,
      'banks': banks.map((b) => {
        'name': b.name,
        'type': b.type,
        'country': b.country,
        'fd_rates': b.fdRates,
        'rd_rates': b.rdRates,
        'savings_rate': b.savingsRate,
      }).toList(),
    };
  }
}

class MarketData {
  final Map<String, dynamic> data;
  MarketData(this.data);

  factory MarketData.fromJson(Map<String, dynamic> json) {
    return MarketData(json);
  }

  Map<String, dynamic> toJson() => data;
}

class BankRateApiService {
  static String baseUrl = 'https://backend-ten-livid-14.vercel.app/api';
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  static const String _cacheKey = 'cached_bank_rates';
  static const String _marketCacheKey = 'cached_market_data';

  static Future<BankRateResponse> fetchRates() async {
    try {
      final response = await _dio.get('$baseUrl/rates');
      if (response.statusCode == 200) {
        final data = BankRateResponse.fromJson(response.data);
        await cacheRates(data);
        return data;
      }
      throw Exception('Failed to load rates');
    } catch (e) {
      final cached = await loadCachedRates();
      if (cached != null) return cached;
      throw e;
    }
  }

  static Future<List<BankInfo>> fetchTopBanks(String duration, {int limit = 10}) async {
    try {
      final response = await _dio.get('$baseUrl/rates/top', queryParameters: {
        'duration': duration,
        'limit': limit,
      });
      if (response.statusCode == 200) {
        var list = response.data as List;
        return list.map((b) => BankInfo(
          name: b['name'] ?? '',
          type: b['type'] ?? '',
          country: b['country'] ?? 'India',
          fdRates: Map<String, double>.from((b['fd_rates'] ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
          rdRates: Map<String, double>.from((b['rd_rates'] ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
          savingsRate: b['savings_rate']?.toDouble(),
          lastUpdated: 'Live',
          shortName: b['short_name'] ?? '',
          established: b['established'] ?? '',
          headquarters: b['headquarters'] ?? '',
          totalBranches: b['total_branches'] ?? '',
          website: b['website'] ?? '',
          customerCare: b['customer_care'] ?? '',
          seniorCitizenExtra: (b['senior_citizen_extra'] ?? 0.50).toDouble(),
          offers: List<String>.from(b['offers'] ?? []),
          minFdAmount: b['min_fd_amount'] ?? 1000,
          maxFdTenure: b['max_fd_tenure'] ?? '10 years',
          features: List<String>.from(b['features'] ?? []),
        )).toList();
      }
      throw Exception('Failed to load top banks');
    } catch (e) {
      throw e; // Handled by fallback in BankDataService
    }
  }

  static Future<MarketData> fetchMarketData() async {
    try {
      final response = await _dio.get('$baseUrl/market');
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString(_marketCacheKey, jsonEncode(response.data));
        return MarketData.fromJson(response.data);
      }
      throw Exception('Failed to load market data');
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_marketCacheKey);
      if (cachedStr != null) {
        return MarketData.fromJson(jsonDecode(cachedStr));
      }
      throw e;
    }
  }

  static Future<void> cacheRates(BankRateResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(response.toJson()));
  }

  static Future<BankRateResponse?> loadCachedRates() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedStr = prefs.getString(_cacheKey);
    if (cachedStr != null) {
      try {
        return BankRateResponse.fromJson(jsonDecode(cachedStr));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static bool isCacheStale(String lastUpdated) {
    try {
      final updatedTime = DateTime.parse(lastUpdated);
      final difference = DateTime.now().difference(updatedTime);
      return difference.inHours >= 6;
    } catch (e) {
      return true;
    }
  }
}
