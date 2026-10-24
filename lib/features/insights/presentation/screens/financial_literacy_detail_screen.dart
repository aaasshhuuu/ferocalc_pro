import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/topic_translation.dart';
import '../../../../core/services/financial_literacy_translation_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/financial_literacy_language_selector.dart';
import '../../../../core/widgets/glassmorphic_card.dart';

/// Dedicated responsive detail screen for an educational topic in Financial Literacy.
class FinancialLiteracyDetailScreen extends StatelessWidget {
  const FinancialLiteracyDetailScreen({
    super.key,
    required this.topicId,
  });

  final String topicId;

  static const Color gold = Color(0xFFC9A96E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: FinancialLiteracyTranslationService.instance,
      builder: (context, _) {
        final service = FinancialLiteracyTranslationService.instance;
        final topic = service.getTranslatedTopicById(topicId);

        if (topic == null) {
          return Scaffold(
            appBar: CustomAppBar(
              title: service.getUiString('topicNotFound'),
              showBackButton: true,
              actions: const [FinancialLiteracyLanguageSelector(compact: true)],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: GlassmorphicCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 56,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          service.getUiString('topicNotFound'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The requested financial literacy topic could not be found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              context.go('/financial-literacy');
                            }
                          },
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: Text(service.getUiString('returnToHub')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.grey[50],
          appBar: CustomAppBar(
            title: topic.title,
            showBackButton: true,
            actions: const [FinancialLiteracyLanguageSelector(compact: true)],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: Responsive.screenPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Banner Card
                      _buildHeaderCard(context, topic, isDark),
                      const SizedBox(height: 16),

                      // What is it?
                      _buildContentCard(
                        title: service.getUiString('whatIsIt'),
                        icon: Icons.help_outline_rounded,
                        content: topic.whatIsIt,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // Why it matters
                      _buildContentCard(
                        title: service.getUiString('whyItMatters'),
                        icon: Icons.stars_rounded,
                        content: topic.whyItMatters,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // How it works
                      _buildContentCard(
                        title: service.getUiString('howItWorks'),
                        icon: Icons.lightbulb_outline_rounded,
                        content: topic.howItWorks,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // Formula or Framework
                      if (topic.formulaOrFramework != null) ...[
                        _buildFormulaCard(
                          title: service.getUiString('formulaOrFramework'),
                          formula: topic.formulaOrFramework!,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Example
                      if (topic.example != null) ...[
                        _buildExampleCard(
                          title: service.getUiString('practicalExample'),
                          example: topic.example!,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Practical Uses
                      if (topic.practicalUses.isNotEmpty) ...[
                        _buildListCard(
                          title: service.getUiString('practicalApplications'),
                          icon: Icons.checklist_rounded,
                          items: topic.practicalUses,
                          bulletColor: gold,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Important Points
                      if (topic.importantPoints.isNotEmpty) ...[
                        _buildListCard(
                          title: service.getUiString('keyTakeaways'),
                          icon: Icons.check_circle_outline_rounded,
                          items: topic.importantPoints,
                          bulletColor: Colors.tealAccent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Limitations
                      if (topic.limitations.isNotEmpty) ...[
                        _buildListCard(
                          title: service.getUiString('considerations'),
                          icon: Icons.warning_amber_rounded,
                          items: topic.limitations,
                          bulletColor: Colors.amber,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Educational Disclaimer
                      if (topic.disclaimer != null) ...[
                        _buildDisclaimerCard(topic.disclaimer!, isDark),
                        const SizedBox(height: 16),
                      ],

                      // Related Calculator Action
                      if (topic.relatedCalculatorRoute != null) ...[
                        _buildRelatedCalculatorButton(context, topic, isDark, service),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(BuildContext context, TranslatedTopic topic, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: topic.isImportant ? gold : gold.withValues(alpha: 0.3),
          width: topic.isImportant ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(topic.canonical.icon, color: gold, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: gold.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            topic.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: gold,
                            ),
                          ),
                        ),
                        if (topic.isImportant)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                SizedBox(width: 4),
                                Text(
                                  'Foundational',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            topic.shortDescription,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard({
    required String title,
    required IconData icon,
    required String content,
    required bool isDark,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaCard({
    required String title,
    required String formula,
    required bool isDark,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.functions_rounded, size: 18, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gold.withValues(alpha: 0.3)),
            ),
            child: Text(
              formula,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8A6D3B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard({
    required String title,
    required String example,
    required bool isDark,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, size: 18, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gold.withValues(alpha: 0.3)),
            ),
            child: Text(
              example,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard({
    required String title,
    required IconData icon,
    required List<String> items,
    required Color bulletColor,
    required bool isDark,
  }) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Icon(Icons.circle, size: 6, color: bulletColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard(String disclaimer, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900]?.withValues(alpha: 0.6) : Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 20, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              disclaimer,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: isDark ? Colors.white60 : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedCalculatorButton(
    BuildContext context,
    TranslatedTopic topic,
    bool isDark,
    FinancialLiteracyTranslationService service,
  ) {
    return ElevatedButton.icon(
      key: ValueKey('related_calc_button_${topic.id}'),
      onPressed: () => context.push(topic.relatedCalculatorRoute!),
      icon: const Icon(Icons.calculate_rounded, size: 20),
      label: Text(topic.relatedCalculatorLabel ?? service.getUiString('openCalculator')),
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
