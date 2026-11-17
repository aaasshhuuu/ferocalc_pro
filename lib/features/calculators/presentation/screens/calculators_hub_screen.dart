import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../data/services/calculator_preferences_service.dart';
import '../../domain/models/calculator_metadata.dart';

class CalculatorsHubScreen extends StatefulWidget {

  const CalculatorsHubScreen({
    Key? key,
    this.preferencesService,
  }) : super(key: key);
  final CalculatorPreferencesService? preferencesService;

  @override
  State<CalculatorsHubScreen> createState() => _CalculatorsHubScreenState();
}

class _CalculatorsHubScreenState extends State<CalculatorsHubScreen> {
  late final TextEditingController _searchController;
  late final CalculatorPreferencesService? _prefs;

  String _searchQuery = '';
  String _selectedCategoryKey = 'all'; // 'all', 'favorites', or category name
  final Map<String, bool> _expandedSections = {};

  static const Color _gold = Color(0xFFC9A96E);
  static const Color _cyan = Color(0xFF00D2D3);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    // Resolve preferences service from widget prop or GetIt fallback
    _prefs = widget.preferencesService ??
        (GetIt.I.isRegistered<CalculatorPreferencesService>()
            ? GetIt.I<CalculatorPreferencesService>()
            : null);

    _prefs?.addListener(_onPreferencesChanged);

    // Initialize all category sections expanded
    for (final cat in CalculatorCategory.values) {
      _expandedSections[cat.name] = true;
    }
  }

  void _onPreferencesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _prefs?.removeListener(_onPreferencesChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onCalculatorTap(CalculatorMeta calc) {
    _prefs?.recordLaunch(calc.id);
    context.push(calc.destinationRoute);
  }

  Future<void> _toggleFavorite(String id) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.toggleFavorite(id);
  }

  Future<void> _showClearRecentDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.history, color: _gold, size: 24),
              SizedBox(width: 8),
              Text(
                'Clear Recent History?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'This will clear all recently launched calculators from your history. Your pinned favorites will remain intact.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Clear History'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _prefs?.clearRecent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = Responsive.isCompact(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final int crossAxisCount = isCompact || textScale > 1.3
        ? 1
        : Responsive.gridCrossAxisCount(
            context,
            mobile: 2,
            tablet: 3,
            desktop: 4,
          );

    final favoriteIds = _prefs?.getFavoriteIds().toSet() ?? <String>{};
    final recentCalculators = _prefs?.getRecentCalculators() ?? <CalculatorMeta>[];
    final favoritesList = _prefs?.getFavorites() ?? <CalculatorMeta>[];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[50],
        appBar: const CustomAppBar(title: 'Calculators', showBackButton: false),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: CustomScrollView(
                slivers: [
                  // 1. Search Bar Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search by name, category, or keyword...',
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: isDark ? Colors.white54 : Colors.black45,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                            });
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: isDark ? Theme.of(context).cardColor : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: _gold, width: 1.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val.toLowerCase().trim();
                                  });
                                },
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${_getFilteredCount(favoriteIds)} matching calculators found',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Financial Insights & Cash Flow Dashboard Banner
                  if (_searchQuery.isEmpty && _selectedCategoryKey == 'all')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: InkWell(
                              key: const ValueKey('hub_financial_insights_banner'),
                              onTap: () => context.push('/financial-insights'),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                        : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _gold.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _gold.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.auto_graph_rounded, color: _gold, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  'Personalized Financial Insights',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isDark ? Colors.white : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: _gold,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'DASHBOARD',
                                                  style: TextStyle(
                                                    color: Colors.black87,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Cash flow planner, emergency runway & goal intelligence',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, color: _gold, size: 14),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 2. Favorites Quick Row (when browsing All with no search query)
                  if (_searchQuery.isEmpty &&
                      _selectedCategoryKey == 'all' &&
                      favoritesList.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star, color: _gold, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Pinned Favorites',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedCategoryKey = 'favorites';
                                    });
                                  },
                                  child: const Text(
                                    'View All',
                                    style: TextStyle(color: _gold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 94,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: favoritesList.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final calc = favoritesList[index];
                                  return _CompactFavoriteCard(
                                    calc: calc,
                                    isDark: isDark,
                                    onTap: () => _onCalculatorTap(calc),
                                    onFavoriteToggle: () => _toggleFavorite(calc.id),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Recently Used Section (when browsing All with no search query)
                  if (_searchQuery.isEmpty &&
                      _selectedCategoryKey == 'all' &&
                      recentCalculators.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.history, color: _cyan, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Recently Used',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _showClearRecentDialog,
                                  icon: const Icon(Icons.clear_all, size: 16, color: Colors.redAccent),
                                  label: const Text(
                                    'Clear',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 84,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: recentCalculators.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final calc = recentCalculators[index];
                                  return _RecentCalculatorChip(
                                    calc: calc,
                                    isDark: isDark,
                                    onTap: () => _onCalculatorTap(calc),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 4. Category Selector Filter Chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildFilterChip(
                              label: 'All (${CalculatorRegistry.totalCount})',
                              key: 'all',
                              icon: Icons.grid_view,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Favorites (${favoriteIds.length})',
                              key: 'favorites',
                              icon: Icons.star,
                            ),
                            const SizedBox(width: 8),
                            ...CalculatorCategory.values.map((cat) {
                              final count = CalculatorRegistry.getByCategory(cat).length;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildFilterChip(
                                  label: '${cat.displayName} ($count)',
                                  key: cat.name,
                                  icon: cat.icon,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 5. Categorized Calculator Content
                  ..._buildCalculatorSlivers(
                    crossAxisCount: crossAxisCount,
                    isDark: isDark,
                    favoriteIds: favoriteIds,
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String key,
    required IconData icon,
  }) {
    final isSelected = _selectedCategoryKey == key;
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.black87 : _gold,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.black87 : null,
          fontSize: 13,
        ),
      ),
      backgroundColor: Colors.transparent,
      selectedColor: _gold,
      side: BorderSide(
        color: isSelected ? _gold : _gold.withValues(alpha: 0.35),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() {
          _selectedCategoryKey = key;
        });
      },
    );
  }

  int _getFilteredCount(Set<String> favoriteIds) {
    if (_selectedCategoryKey == 'favorites') {
      return CalculatorRegistry.search(
        _searchQuery,
        favoritesOnly: true,
        favoriteIds: favoriteIds,
      ).length;
    }
    final category = _selectedCategoryKey == 'all'
        ? null
        : CalculatorCategory.values.firstWhere((c) => c.name == _selectedCategoryKey);

    return CalculatorRegistry.search(_searchQuery, category: category).length;
  }

  List<Widget> _buildCalculatorSlivers({
    required int crossAxisCount,
    required bool isDark,
    required Set<String> favoriteIds,
  }) {
    // A. Active Search Mode
    if (_searchQuery.isNotEmpty) {
      final category = _selectedCategoryKey == 'all' || _selectedCategoryKey == 'favorites'
          ? null
          : CalculatorCategory.values.firstWhere((c) => c.name == _selectedCategoryKey);

      final results = CalculatorRegistry.search(
        _searchQuery,
        category: category,
        favoritesOnly: _selectedCategoryKey == 'favorites',
        favoriteIds: favoriteIds,
      );

      if (results.isEmpty) {
        return [_buildEmptyState(isDark)];
      }

      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.15,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final calc = results[index];
                return _CalculatorCard(
                  calc: calc,
                  isDark: isDark,
                  isFavorite: favoriteIds.contains(calc.id),
                  onTap: () => _onCalculatorTap(calc),
                  onFavoriteToggle: () => _toggleFavorite(calc.id),
                );
              },
              childCount: results.length,
            ),
          ),
        ),
      ];
    }

    // B. Favorites Filter Mode
    if (_selectedCategoryKey == 'favorites') {
      final results = CalculatorRegistry.all.where((c) => favoriteIds.contains(c.id)).toList();
      if (results.isEmpty) {
        return [_buildEmptyFavoritesState(isDark)];
      }

      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.15,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final calc = results[index];
                return _CalculatorCard(
                  calc: calc,
                  isDark: isDark,
                  isFavorite: true,
                  onTap: () => _onCalculatorTap(calc),
                  onFavoriteToggle: () => _toggleFavorite(calc.id),
                );
              },
              childCount: results.length,
            ),
          ),
        ),
      ];
    }

    // C. Single Category Filter Mode
    if (_selectedCategoryKey != 'all') {
      final category = CalculatorCategory.values.firstWhere((c) => c.name == _selectedCategoryKey);
      final results = CalculatorRegistry.getByCategory(category);

      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.15,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final calc = results[index];
                return _CalculatorCard(
                  calc: calc,
                  isDark: isDark,
                  isFavorite: favoriteIds.contains(calc.id),
                  onTap: () => _onCalculatorTap(calc),
                  onFavoriteToggle: () => _toggleFavorite(calc.id),
                );
              },
              childCount: results.length,
            ),
          ),
        ),
      ];
    }

    // D. "All" View: Grouped by Category with headers
    // Note: other (General Interest) placed first to ensure immediate viewport availability
    final orderedCategories = [
      CalculatorCategory.other,
      CalculatorCategory.loans,
      CalculatorCategory.investments,
      CalculatorCategory.deposits,
      CalculatorCategory.tax,
      CalculatorCategory.stocks,
      CalculatorCategory.retirement,
    ];

    final List<Widget> slivers = [];
    for (final category in orderedCategories) {
      final items = CalculatorRegistry.getByCategory(category);
      if (items.isEmpty) continue;

      final isExpanded = _expandedSections[category.name] ?? true;
      final sectionTitle = category == CalculatorCategory.other ? 'General Interest' : category.displayName;

      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedSections[category.name] = !isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _gold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(category.icon, size: 20, color: _gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sectionTitle,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${items.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: isExpanded ? 0.0 : -0.25,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more, color: _gold, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      if (isExpanded) {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.15,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final calc = items[index];
                  return _CalculatorCard(
                    calc: calc,
                    isDark: isDark,
                    isFavorite: favoriteIds.contains(calc.id),
                    onTap: () => _onCalculatorTap(calc),
                    onFavoriteToggle: () => _toggleFavorite(calc.id),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        );
      }
    }

    return slivers;
  }

  Widget _buildEmptyState(bool isDark) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 56,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(height: 16),
              Text(
                'No calculators found for "$_searchQuery"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching for EMI, FD, SIP, Tax, or Stocks.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear Search'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFavoritesState(bool isDark) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_outline,
                size: 56,
                color: _gold,
              ),
              const SizedBox(height: 16),
              Text(
                'No Favorite Calculators Yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the star icon on any calculator card to pin your favorite tools for instant access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedCategoryKey = 'all';
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: const BorderSide(color: _gold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.grid_view, size: 16),
                label: const Text('Browse All Calculators'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standardized card component representing a single calculator.
class _CalculatorCard extends StatelessWidget {

  const _CalculatorCard({
    required this.calc,
    required this.isDark,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });
  final CalculatorMeta calc;
  final bool isDark;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  static const Color _gold = Color(0xFFC9A96E);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${calc.name} calculator. ${calc.shortDescription}',
      child: GlassmorphicCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          key: ValueKey('calc_card_${calc.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: _gold.withValues(alpha: 0.1),
          highlightColor: _gold.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon, Optional Badge, and Favorite Star
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(calc.icon, size: 20, color: _gold),
                  ),
                  const SizedBox(width: 6),
                  if (calc.badgeText != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D2D3).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          calc.badgeText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00D2D3),
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  // Favorite button with generous tap area
                  Semantics(
                    label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    button: true,
                    child: InkResponse(
                      key: ValueKey('fav_btn_${calc.id}'),
                      onTap: onFavoriteToggle,
                      radius: 20,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isFavorite ? Icons.star : Icons.star_border,
                          size: 20,
                          color: isFavorite ? _gold : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Title
              Text(
                calc.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Description
              Text(
                calc.shortDescription,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.25,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),);
  }
}

/// Compact horizontal card for Pinned Favorites.
class _CompactFavoriteCard extends StatelessWidget {

  const _CompactFavoriteCard({
    required this.calc,
    required this.isDark,
    required this.onTap,
    required this.onFavoriteToggle,
  });
  final CalculatorMeta calc;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  static const Color _gold = Color(0xFFC9A96E);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${calc.name} calculator, pinned favorite',
      child: SizedBox(
        width: 145,
        child: GlassmorphicCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(calc.icon, size: 18, color: _gold),
                      const Spacer(),
                      InkResponse(
                        onTap: onFavoriteToggle,
                        radius: 16,
                        child: const Icon(Icons.star, size: 16, color: _gold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    calc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    calc.category.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
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
}

/// Compact chip for recently used calculators.
class _RecentCalculatorChip extends StatelessWidget {

  const _RecentCalculatorChip({
    required this.calc,
    required this.isDark,
    required this.onTap,
  });
  final CalculatorMeta calc;
  final bool isDark;
  final VoidCallback onTap;

  static const Color _cyan = Color(0xFF00D2D3);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${calc.name} calculator, recently used',
      child: SizedBox(
        width: 130,
        child: GlassmorphicCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(calc.icon, size: 16, color: _cyan),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          calc.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    calc.shortDescription,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isDark ? Colors.white38 : Colors.black38,
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
}
