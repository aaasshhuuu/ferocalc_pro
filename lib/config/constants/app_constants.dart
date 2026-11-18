class AppConstants {
  static const String appName = 'FeroCalc';
  static const String appVersion = '1.0.1';

  static const String appPackageName = 'com.ferocalc.app';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$appPackageName';

  // Legal entity
  static const String publisherName = 'Oxygen Inc';
  static const String publisherAddress =
      '149/A Kailash Nagar Soc., Near Lilyawala School, Dumbhal, Surat – 395002, Gujarat, India';

  // Live legal URLs (served from Vercel backend)
  static const String privacyPolicyUrl =
      'https://backend-ten-livid-14.vercel.app/legal/privacy_policy.html';
  static const String termsOfUseUrl =
      'https://backend-ten-livid-14.vercel.app/legal/terms_of_use.html';
  static const String financialDisclaimerUrl =
      'https://backend-ten-livid-14.vercel.app/legal/financial_disclaimer.html';

  // Contact emails
  static const String privacyEmail = 'privacy@ferocalc.app';
  static const String legalEmail = 'legal@ferocalc.app';
  static const String supportEmail = 'ferocalc.app@gmail.com';

  static const int maxBanksToCompare = 10;

  // Default values for calculators
  static const double defaultLoanAmount = 1000000;
  static const double defaultInterestRate = 8.5;
  static const double defaultTenureYears = 10;
  static const double maxLoanAmount = 100000000; // 10 Cr
  static const double maxInterestRate = 30.0;
  static const double maxTenureYears = 40.0;
}
