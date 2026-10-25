import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/financial_management_data.dart';
import '../../../../core/models/financial_management_topic.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';

/// Screen displaying detailed, comprehensive financial management education for a topic.
class FinancialManagementDetailScreen extends StatelessWidget {
  const FinancialManagementDetailScreen({
    Key? key,
    required this.topicId,
  }) : super(key: key);

  final String topicId;

  static const Color gold = Color(0xFFC9A96E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topic = FinancialManagementData.getTopicById(topicId);

    if (topic == null) {
      return Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.grey[50],
        appBar: const CustomAppBar(title: 'Topic Not Found', showBackButton: true),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: GlassmorphicCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Topic Not Found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The requested financial management topic "$topicId" could not be located.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/insights');
                        }
                      },
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Return to Insights'),
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
      appBar: CustomAppBar(title: topic.title, showBackButton: true),
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
                    title: 'What is it?',
                    icon: Icons.help_outline_rounded,
                    content: topic.whatIsIt,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // Why it matters
                  _buildContentCard(
                    title: 'Why It Matters',
                    icon: Icons.stars_rounded,
                    content: topic.whyItMatters,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // How it works
                  _buildContentCard(
                    title: 'How It Works',
                    icon: Icons.lightbulb_outline_rounded,
                    content: topic.howItWorks,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // Formula / Rule (if present)
                  if (topic.formulaOrRule != null) ...[
                    _buildFormulaCard(topic.formulaOrRule!, isDark),
                    const SizedBox(height: 16),
                  ],

                  // Example (if present)
                  if (topic.example != null) ...[
                    _buildExampleCard(topic.example!, isDark),
                    const SizedBox(height: 16),
                  ],

                  // Practical Uses (if present)
                  if (topic.practicalUses.isNotEmpty) ...[
                    _buildListCard(
                      title: 'Practical Applications',
                      icon: Icons.checklist_rounded,
                      items: topic.practicalUses,
                      bulletColor: gold,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Important Points & Limitations
                  if (topic.importantPoints.isNotEmpty) ...[
                    _buildListCard(
                      title: 'Important Points & Limitations',
                      icon: Icons.info_outline_rounded,
                      items: topic.importantPoints,
                      bulletColor: Colors.amber,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Disclaimer
                  if (topic.disclaimer != null) ...[
                    _buildDisclaimerCard(topic.disclaimer!, isDark),
                    const SizedBox(height: 20),
                  ],

                  // Related Calculator Action
                  if (topic.relatedCalculatorRoute != null) ...[
                    _buildRelatedCalculatorButton(context, topic, isDark),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, FinancialManagementTopic topic, bool isDark) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: gold.withAlpha(35),
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withAlpha(80), width: 1.2),
                ),
                child: Icon(topic.icon, color: gold, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            topic.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (topic.isKeyTopic) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: gold.withAlpha(35),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: gold.withAlpha(90), width: 0.8),
                            ),
                            child: const Text(
                              'Key Principle',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: gold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic.shortDescription,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaCard(String formula, bool isDark) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.functions_rounded, size: 18, color: gold),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Formula / Rule Framework',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: gold,
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
              color: isDark ? const Color(0xFF141D27) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gold.withAlpha(60)),
            ),
            child: Text(
              formula,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE2D1A6) : const Color(0xFF6B4E1B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard(String example, bool isDark) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 18, color: gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Practical Example',
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
              color: isDark ? Colors.white.withAlpha(6) : Colors.black.withAlpha(4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Text(
              example,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black87,
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
              Icon(icon, size: 18, color: bulletColor),
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
                    padding: const EdgeInsets.only(top: 5.0, right: 8.0),
                    child: Icon(Icons.circle, size: 6, color: bulletColor),
                  ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(6) : Colors.black.withAlpha(4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              disclaimer,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedCalculatorButton(
    BuildContext context,
    FinancialManagementTopic topic,
    bool isDark,
  ) {
    return ElevatedButton.icon(
      key: ValueKey('related_calc_button_${topic.id}'),
      onPressed: () => context.push(topic.relatedCalculatorRoute!),
      icon: const Icon(Icons.calculate_outlined, size: 18),
      label: Text(
        topic.relatedCalculatorLabel ?? 'Open Related Calculator',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
