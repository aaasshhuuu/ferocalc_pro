import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/financial_literacy_data.dart';
import '../../../../core/models/financial_literacy_topic.dart';
import '../../../../core/models/topic_translation.dart';
import '../../../../core/services/financial_literacy_translation_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/financial_literacy_language_selector.dart';

/// Dedicated Financial Literacy Hub where users can browse, search, and filter educational topics.
class FinancialLiteracyHubScreen extends StatefulWidget {
  const FinancialLiteracyHubScreen({super.key});

  @override
  State<FinancialLiteracyHubScreen> createState() => _FinancialLiteracyHubScreenState();
}

class _FinancialLiteracyHubScreenState extends State<FinancialLiteracyHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = FinancialLiteracyCategories.all;

  static const Color gold = Color(0xFFC9A96E);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategory = FinancialLiteracyCategories.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return ListenableBuilder(
      listenable: FinancialLiteracyTranslationService.instance,
      builder: (context, _) {
        final service = FinancialLiteracyTranslationService.instance;

        final filteredTopics = service.searchTopics(
          query: _searchQuery,
          category: _selectedCategory,
        );

        final importantTopics = FinancialLiteracyData.getImportantTopics();
        final showImportantSection = _searchQuery.trim().isEmpty &&
            _selectedCategory == FinancialLiteracyCategories.all;

        return Scaffold(
          backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.grey[50],
          appBar: CustomAppBar(
            title: service.getUiString('hubTitle'),
            showBackButton: true,
            actions: const [
              FinancialLiteracyLanguageSelector(compact: true),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  padding: Responsive.screenPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Header Banner
                      _buildHeaderBanner(isDark, textColor, service),
                      const SizedBox(height: 16),

                      // 2. Search Field
                      _buildSearchBar(isDark, textColor, service),
                      const SizedBox(height: 14),

                      // 3. Category Filter Chips
                      _buildCategoryChips(isDark),
                      const SizedBox(height: 20),

                      // 4. Important Topics Section (Visible when not actively filtering)
                      if (showImportantSection && importantTopics.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 20, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                service.getUiString('foundationalPrinciples'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildImportantTopicsSection(importantTopics, isDark, textColor, service),
                        const SizedBox(height: 24),
                      ],

                      // 5. Section Heading for All / Filtered Topics
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _getResultsTitle(filteredTopics.length),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_searchQuery.trim().isNotEmpty ||
                              _selectedCategory != FinancialLiteracyCategories.all)
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.refresh_rounded, size: 16, color: gold),
                              label: const Text('Reset', style: TextStyle(color: gold, fontSize: 13)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 6. Topics List or No-Results State
                      if (filteredTopics.isEmpty)
                        _buildNoResultsState(isDark, service)
                      else
                        _buildTopicsList(filteredTopics, isDark, textColor, service),

                      const SizedBox(height: 24),
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

  String _getResultsTitle(int count) {
    if (_searchQuery.trim().isNotEmpty) {
      return 'Search Results ($count)';
    }
    if (_selectedCategory != FinancialLiteracyCategories.all) {
      return '$_selectedCategory ($count)';
    }
    return 'All Topics ($count)';
  }

  Widget _buildHeaderBanner(
    bool isDark,
    Color textColor,
    FinancialLiteracyTranslationService service,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.getUiString('hubBannerTitle'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service.getUiString('hubSubtitle'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Explore fundamental personal finance concepts, worked mathematical rules, and structured explanations to make informed financial decisions.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? Colors.white60 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    bool isDark,
    Color textColor,
    FinancialLiteracyTranslationService service,
  ) {
    return TextField(
      key: const ValueKey('literacy_search_field'),
      controller: _searchController,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText: service.getUiString('searchHint'),
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.black38,
          fontSize: 13.5,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: gold, size: 22),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                key: const ValueKey('literacy_search_clear_button'),
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF1A2634) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        key: const ValueKey('category_chips_list'),
        scrollDirection: Axis.horizontal,
        itemCount: FinancialLiteracyCategories.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = FinancialLiteracyCategories.values[index];
          final isSelected = cat == _selectedCategory;
          return ChoiceChip(
            key: ValueKey('category_chip_$cat'),
            label: Text(cat),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedCategory = cat;
                });
              }
            },
            selectedColor: gold,
            backgroundColor: isDark ? const Color(0xFF1A2634) : Colors.white,
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.black
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            side: BorderSide(
              color: isSelected ? gold : (isDark ? Colors.white24 : Colors.black12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          );
        },
      ),
    );
  }

  Widget _buildImportantTopicsSection(
    List<FinancialLiteracyTopic> importantTopics,
    bool isDark,
    Color textColor,
    FinancialLiteracyTranslationService service,
  ) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: importantTopics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final topic = importantTopics[index];
          final translated = service.getTranslatedTopic(topic);
          return _buildImportantTopicCard(translated, isDark, textColor);
        },
      ),
    );
  }

  Widget _buildImportantTopicCard(
    TranslatedTopic topic,
    bool isDark,
    Color textColor,
  ) {
    return Container(
      key: ValueKey('important_topic_card_${topic.id}'),
      width: 230,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/financial-literacy/${topic.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(topic.canonical.icon, color: gold, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        topic.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    topic.category,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: gold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    topic.shortDescription,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopicsList(
    List<FinancialLiteracyTopic> topics,
    bool isDark,
    Color textColor,
    FinancialLiteracyTranslationService service,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: topics.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final topic = topics[index];
        final translated = service.getTranslatedTopic(topic);
        return _buildTopicRowCard(translated, isDark, textColor);
      },
    );
  }

  Widget _buildTopicRowCard(
    TranslatedTopic topic,
    bool isDark,
    Color textColor,
  ) {
    return Container(
      key: ValueKey('literacy_card_${topic.id}'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: topic.isImportant
              ? gold.withValues(alpha: 0.4)
              : (isDark ? Colors.white10 : Colors.black12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('literacy_inkwell_${topic.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/financial-literacy/${topic.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(topic.canonical.icon, color: gold, size: 22),
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
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (topic.isImportant) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: gold.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              topic.category,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: gold,
                              ),
                            ),
                          ),
                          if (topic.relatedCalculatorRoute != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Calculator',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.lightBlueAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        topic.shortDescription,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: gold, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState(
    bool isDark,
    FinancialLiteracyTranslationService service,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(height: 12),
          Text(
            service.getUiString('noResults'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search query or selecting a different category filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: const ValueKey('literacy_clear_filters_button'),
            onPressed: _clearFilters,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(service.getUiString('clearFilters')),
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
