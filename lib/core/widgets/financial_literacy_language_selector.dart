import 'package:flutter/material.dart';

import '../models/financial_literacy_language.dart';
import '../services/financial_literacy_translation_service.dart';

/// Reusable language selector widget for the Financial Literacy Hub and Detail screens.
class FinancialLiteracyLanguageSelector extends StatelessWidget {
  const FinancialLiteracyLanguageSelector({
    super.key,
    this.compact = false,
  });

  /// When true, renders a compact icon/pill suited for app bar action areas.
  final bool compact;

  static const Color gold = Color(0xFFC9A96E);

  void _showLanguageBottomSheet(BuildContext context) {
    final service = FinancialLiteracyTranslationService.instance;
    final current = service.currentLanguage;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A2634) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.language_rounded, color: gold, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      service.getUiString('selectLanguage'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...FinancialLiteracyLanguage.values.map((lang) {
                  final isSelected = lang == current;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Material(
                      color: isSelected
                          ? gold.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        key: ValueKey('language_option_${lang.code}'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? gold
                                : (isDark ? Colors.white12 : Colors.black12),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              isSelected ? gold : (isDark ? Colors.white10 : Colors.black12),
                          child: Text(
                            lang.code.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                        title: Text(
                          lang.nativeName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          lang.englishName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: gold, size: 22)
                            : null,
                        onTap: () {
                          service.setLanguage(lang);
                          Navigator.of(bottomSheetContext).pop();
                        },
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FinancialLiteracyTranslationService.instance,
      builder: (context, _) {
        final currentLang =
            FinancialLiteracyTranslationService.instance.currentLanguage;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Semantics(
          label: 'Change Financial Literacy language. Current: ${currentLang.englishName}',
          button: true,
          child: InkWell(
            key: const ValueKey('financial_literacy_language_selector'),
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showLanguageBottomSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2634) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: gold.withValues(alpha: 0.4), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate_rounded, size: 16, color: gold),
                  const SizedBox(width: 5),
                  Text(
                    currentLang.nativeName,
                    key: const ValueKey('selected_language_badge'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
