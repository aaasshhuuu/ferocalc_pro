import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/financial_literacy_data.dart';
import '../data/financial_management_data.dart';
import '../data/translations/financial_literacy_gu.dart';
import '../data/translations/financial_literacy_hi.dart';
import '../data/translations/financial_literacy_ui_strings.dart';
import '../models/financial_literacy_language.dart';
import '../models/financial_literacy_topic.dart';
import '../models/topic_translation.dart';

/// Centralized service managing translations, persistence, and fallbacks
/// for the Financial Literacy section.
class FinancialLiteracyTranslationService extends ChangeNotifier {
  FinancialLiteracyTranslationService({SharedPreferences? preferences})
      : _preferences = preferences,
        _currentLanguage = _resolveInitialLanguage(preferences);

  static const String languagePreferenceKey =
      'financial_literacy_language_code';

  static FinancialLiteracyTranslationService? _instance;

  /// Global accessor with safe fallback initialization.
  static FinancialLiteracyTranslationService get instance {
    _instance ??= FinancialLiteracyTranslationService();
    return _instance!;
  }

  /// Explicit initialization method (called during app startup / DI).
  static void init(SharedPreferences? preferences) {
    _instance = FinancialLiteracyTranslationService(preferences: preferences);
  }

  /// Resets instance for isolated unit and widget tests.
  @visibleForTesting
  static void resetForTesting({
    SharedPreferences? preferences,
    FinancialLiteracyLanguage initialLanguage = FinancialLiteracyLanguage.english,
  }) {
    _instance = FinancialLiteracyTranslationService(preferences: preferences)
      .._currentLanguage = initialLanguage;
  }

  final SharedPreferences? _preferences;
  FinancialLiteracyLanguage _currentLanguage;

  /// Current active language.
  FinancialLiteracyLanguage get currentLanguage => _currentLanguage;

  static FinancialLiteracyLanguage _resolveInitialLanguage(
    SharedPreferences? preferences,
  ) {
    final savedCode = preferences?.getString(languagePreferenceKey);
    return FinancialLiteracyLanguage.fromCode(savedCode);
  }

  /// Updates the active language, persists to [SharedPreferences], and notifies UI listeners.
  Future<void> setLanguage(FinancialLiteracyLanguage language) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    notifyListeners();

    try {
      await _preferences?.setString(languagePreferenceKey, language.code);
    } catch (e) {
      debugPrint('Failed to save Financial Literacy language: $e');
    }
  }

  /// Returns the translated representation of a [FinancialLiteracyTopic].
  ///
  /// Falls back deterministically to English canonical fields if the translation
  /// is missing for any individual field or topic.
  TranslatedTopic getTranslatedTopic(
    FinancialLiteracyTopic canonical, [
    FinancialLiteracyLanguage? language,
  ]) {
    final targetLang = language ?? _currentLanguage;

    if (targetLang == FinancialLiteracyLanguage.english) {
      return TranslatedTopic(
        canonical: canonical,
        language: FinancialLiteracyLanguage.english,
      );
    }

    final translation = _lookupTranslation(canonical.id, targetLang);

    return TranslatedTopic(
      canonical: canonical,
      language: targetLang,
      translation: translation,
    );
  }

  /// Finds and returns the translated topic by [id], searching both Financial Literacy
  /// and Financial Management registries.
  TranslatedTopic? getTranslatedTopicById(
    String id, [
    FinancialLiteracyLanguage? language,
  ]) {
    // 1. Try FinancialLiteracyData
    final topic = FinancialLiteracyData.getTopicById(id);
    if (topic != null) {
      return getTranslatedTopic(topic, language);
    }

    // 2. Try FinancialManagementData
    final mgmtTopic = FinancialManagementData.getTopicById(id);
    if (mgmtTopic != null) {
      final adapted = FinancialLiteracyTopic.fromFinancialManagement(
        managementTopic: mgmtTopic,
        category: 'Personal Finance',
      );
      return getTranslatedTopic(adapted, language);
    }

    return null;
  }

  /// Returns all translated topics.
  List<TranslatedTopic> getAllTranslatedTopics([
    FinancialLiteracyLanguage? language,
  ]) {
    return FinancialLiteracyData.getAllTopics()
        .map((t) => getTranslatedTopic(t, language))
        .toList();
  }

  /// Returns all important translated topics.
  List<TranslatedTopic> getImportantTranslatedTopics([
    FinancialLiteracyLanguage? language,
  ]) {
    return FinancialLiteracyData.getImportantTopics()
        .map((t) => getTranslatedTopic(t, language))
        .toList();
  }

  /// Returns localized UI string for section titles, labels, and buttons.
  String getUiString(String key, [FinancialLiteracyLanguage? language]) {
    return FinancialLiteracyUiStrings.get(
      key,
      language ?? _currentLanguage,
    );
  }

  /// Searches topics across canonical English metadata as well as active language translations.
  List<FinancialLiteracyTopic> searchTopics({
    required String query,
    String category = FinancialLiteracyCategories.all,
    FinancialLiteracyLanguage? language,
  }) {
    final targetLang = language ?? _currentLanguage;
    final cleanQuery = query.trim().toLowerCase();
    final canonicalResults = FinancialLiteracyData.searchTopics(
      query: query,
      category: category,
    );

    if (cleanQuery.isEmpty || targetLang == FinancialLiteracyLanguage.english) {
      return canonicalResults;
    }

    // Also match translated titles/descriptions in target language
    final allCategoryTopics =
        FinancialLiteracyData.getTopicsByCategory(category);
    final results = <FinancialLiteracyTopic>{...canonicalResults};

    for (final topic in allCategoryTopics) {
      final translated = getTranslatedTopic(topic, targetLang);
      if (translated.title.toLowerCase().contains(cleanQuery) ||
          translated.shortDescription.toLowerCase().contains(cleanQuery)) {
        results.add(topic);
      }
    }

    return results.toList();
  }

  /// Looks up translation dictionary for the given topic ID and language.
  TopicTranslation? _lookupTranslation(
    String topicId,
    FinancialLiteracyLanguage language,
  ) {
    final normalizedId = topicId.toLowerCase().replaceAll('_', '-').trim();

    if (language == FinancialLiteracyLanguage.hindi) {
      return financialLiteracyHindiTranslations[normalizedId];
    } else if (language == FinancialLiteracyLanguage.gujarati) {
      return financialLiteracyGujaratiTranslations[normalizedId];
    }

    return null;
  }
}
