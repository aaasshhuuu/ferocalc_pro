/// Supported languages for the Financial Literacy section.
enum FinancialLiteracyLanguage {
  english('en', 'English', 'English'),
  hindi('hi', 'Hindi', 'हिन्दी'),
  gujarati('gu', 'Gujarati', 'ગુજરાતી');

  const FinancialLiteracyLanguage(this.code, this.englishName, this.nativeName);

  final String code;
  final String englishName;
  final String nativeName;

  /// Safe parser that falls back to English if code is null, unknown, or corrupted.
  static FinancialLiteracyLanguage fromCode(String? code) {
    if (code == null) return FinancialLiteracyLanguage.english;
    final normalized = code.trim().toLowerCase();
    for (final lang in FinancialLiteracyLanguage.values) {
      if (lang.code.toLowerCase() == normalized ||
          lang.englishName.toLowerCase() == normalized) {
        return lang;
      }
    }
    return FinancialLiteracyLanguage.english;
  }
}
