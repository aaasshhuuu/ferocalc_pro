// Analytics Service — stub for initial run
// Enable after adding 'firebase_analytics' package

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  Future<void> logEvent({required String name, Map<String, dynamic>? parameters}) async {}
  Future<void> logScreenView({required String screenName}) async {}
  Future<void> setUserId(String? id) async {}
  Future<void> logCalculation(String calculatorType) async {}
  Future<void> logComparison(int bankCount) async {}
}
