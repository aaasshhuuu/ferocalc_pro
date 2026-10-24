import 'financial_literacy_language.dart';
import 'financial_literacy_topic.dart';

/// Holds translated textual fields for an educational topic.
class TopicTranslation {
  const TopicTranslation({
    this.title,
    this.shortDescription,
    this.whatIsIt,
    this.whyItMatters,
    this.howItWorks,
    this.formulaOrFramework,
    this.example,
    this.practicalUses,
    this.importantPoints,
    this.limitations,
    this.disclaimer,
    this.relatedCalculatorLabel,
  });

  final String? title;
  final String? shortDescription;
  final String? whatIsIt;
  final String? whyItMatters;
  final String? howItWorks;
  final String? formulaOrFramework;
  final String? example;
  final List<String>? practicalUses;
  final List<String>? importantPoints;
  final List<String>? limitations;
  final String? disclaimer;
  final String? relatedCalculatorLabel;
}

/// Represents the resolved view of a [FinancialLiteracyTopic] in a target [language].
///
/// Any field missing in the translation automatically and deterministically falls
/// back to the canonical English [canonical] topic field.
class TranslatedTopic {
  TranslatedTopic({
    required this.canonical,
    required this.language,
    TopicTranslation? translation,
  })  : title = _resolve(translation?.title, canonical.title),
        shortDescription =
            _resolve(translation?.shortDescription, canonical.shortDescription),
        whatIsIt = _resolve(translation?.whatIsIt, canonical.whatIsIt),
        whyItMatters = _resolve(translation?.whyItMatters, canonical.whyItMatters),
        howItWorks = _resolve(translation?.howItWorks, canonical.howItWorks),
        formulaOrFramework = translation?.formulaOrFramework ?? canonical.formulaOrFramework,
        example = translation?.example ?? canonical.example,
        practicalUses = (translation?.practicalUses != null &&
                translation!.practicalUses!.isNotEmpty)
            ? List.unmodifiable(translation.practicalUses!)
            : canonical.practicalUses,
        importantPoints = (translation?.importantPoints != null &&
                translation!.importantPoints!.isNotEmpty)
            ? List.unmodifiable(translation.importantPoints!)
            : canonical.importantPoints,
        limitations = (translation?.limitations != null &&
                translation!.limitations!.isNotEmpty)
            ? List.unmodifiable(translation.limitations!)
            : canonical.limitations,
        disclaimer = translation?.disclaimer ?? canonical.disclaimer,
        relatedCalculatorLabel = translation?.relatedCalculatorLabel ??
            canonical.relatedCalculatorLabel;

  static String _resolve(String? translated, String fallback) {
    if (translated == null || translated.trim().isEmpty) {
      return fallback;
    }
    return translated;
  }

  final FinancialLiteracyTopic canonical;
  final FinancialLiteracyLanguage language;

  final String title;
  final String shortDescription;
  final String whatIsIt;
  final String whyItMatters;
  final String howItWorks;
  final String? formulaOrFramework;
  final String? example;
  final List<String> practicalUses;
  final List<String> importantPoints;
  final List<String> limitations;
  final String? disclaimer;
  final String? relatedCalculatorLabel;

  /// Whether this view represents translated content (non-English).
  bool get isTranslated => language != FinancialLiteracyLanguage.english;

  /// Underlying immutable topic ID.
  String get id => canonical.id;

  /// Canonical category.
  String get category => canonical.category;

  /// Educational priority flag.
  bool get isImportant => canonical.isImportant;

  /// Direct route to related calculator.
  String? get relatedCalculatorRoute => canonical.relatedCalculatorRoute;
}
