// Ad Service — stub for initial run
// Enable after adding 'google_mobile_ads' package and setting up AdMob

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  Future<void> initialize() async {
    // TODO: Initialize MobileAds after adding google_mobile_ads
  }

  void loadBannerAd() {
    // Stub
  }

  Future<void> showInterstitialAd() async {
    // Stub
  }

  Future<void> showRewardedAd({required Function onRewarded}) async {
    // Stub — just call the reward directly
    onRewarded();
  }

  void dispose() {}
}
