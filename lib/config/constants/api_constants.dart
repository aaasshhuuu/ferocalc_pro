class ApiConstants {
  static const String baseUrl = 'https://api.fincalcpro.com/v1'; // Placeholder URL
  static const int connectTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000;
  
  static const String loginEndpoint = '/auth/login';
  static const String syncEndpoint = '/sync';
  static const String getRatesEndpoint = '/rates';
}
