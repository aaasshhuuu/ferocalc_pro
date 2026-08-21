// Network info — stub without connectivity_plus
// Enable after adding connectivity_plus package

class NetworkInfo {
  Future<bool> get isConnected async {
    // Simple connectivity check - always returns true for now
    // Replace with connectivity_plus check when package is enabled
    return true;
  }
}
