// Sync Service — stub for initial run
// Enable after adding 'cloud_firestore' package

class SyncService {
  factory SyncService() => _instance;
  SyncService._internal();
  static final SyncService _instance = SyncService._internal();

  Future<void> syncCalculations() async {}
  Future<void> syncFavorites() async {}
  Future<void> syncHistory() async {}
  Future<void> syncSettings() async {}
  Future<void> syncAll() async {}
  bool get isSyncing => false;
}
