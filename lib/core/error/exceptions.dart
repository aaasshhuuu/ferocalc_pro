class ServerException implements Exception {
  ServerException({this.message = 'Server Error'});
  final String message;
}

class CacheException implements Exception {
  CacheException({this.message = 'Cache Error'});
  final String message;
}

class NetworkException implements Exception {
  NetworkException({this.message = 'Network Error'});
  final String message;
}
