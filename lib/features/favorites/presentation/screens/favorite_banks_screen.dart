import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/bank_data.dart';
import '../../../../core/models/bank.dart';
import '../../../../core/services/verified_rate_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/models/favorite_bank.dart';
import '../bloc/favorite_banks_bloc.dart';
import '../bloc/favorite_banks_event.dart';
import '../bloc/favorite_banks_state.dart';

class FavoriteBanksScreen extends StatefulWidget {
  const FavoriteBanksScreen({Key? key, this.initialTab = 0}) : super(key: key);

  /// 0 for Favorites, 1 for Catalog
  final int initialTab;

  @override
  State<FavoriteBanksScreen> createState() => _FavoriteBanksScreenState();
}

class _FavoriteBanksScreenState extends State<FavoriteBanksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Bank> _catalogBanks = [];
  Set<String> _verifiedBankIds = {};
  bool _isLoadingCatalog = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _loadCatalogAndCoverage();
    context.read<FavoriteBanksBloc>().add(const LoadFavoriteBanks());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogAndCoverage() async {
    try {
      // 1. Fetch live banks and verified rates from backend
      final verifiedBanks = await VerifiedRateService.fetchBanks();
      final ratesRes = await VerifiedRateService.fetchAll(isCallable: null);
      final verifiedIds = ratesRes.rates.map((r) => r.bankId).toSet();

      // 2. Combine with local catalog institutions so all banks are browseable
      final Map<String, Bank> merged = {};

      // Seed with local bank dataset
      for (final info in BankDataService.getAllBanks()) {
        final id = _normalizeBankId(info.name);
        merged[id] = Bank(
          id: id,
          name: info.name,
          shortName: info.shortName.isNotEmpty ? info.shortName : info.name,
          type: _mapType(info.type),
          established: info.established,
          headquarters: info.headquarters,
          totalBranches: info.totalBranches,
          officialWebsite: info.website,
        );
      }

      // Merge verified banks
      for (final b in verifiedBanks) {
        merged[b.id] = b;
      }

      if (mounted) {
        setState(() {
          _catalogBanks = merged.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          _verifiedBankIds = verifiedIds;
          _isLoadingCatalog = false;
        });
      }
    } catch (_) {
      // Offline fallback: Use local bank dataset
      final Map<String, Bank> localMap = {};
      for (final info in BankDataService.getAllBanks()) {
        final id = _normalizeBankId(info.name);
        localMap[id] = Bank(
          id: id,
          name: info.name,
          shortName: info.shortName.isNotEmpty ? info.shortName : info.name,
          type: _mapType(info.type),
          established: info.established,
          headquarters: info.headquarters,
          totalBranches: info.totalBranches,
          officialWebsite: info.website,
        );
      }
      if (mounted) {
        setState(() {
          _catalogBanks = localMap.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          _verifiedBankIds = {};
          _isLoadingCatalog = false;
        });
      }
    }
  }

  String _normalizeBankId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  BankType _mapType(String type) {
    switch (type.toLowerCase()) {
      case 'public':
        return BankType.public;
      case 'small_finance':
        return BankType.smallFinance;
      case 'foreign':
        return BankType.foreign;
      default:
        return BankType.private;
    }
  }

  bool _isVerifiedBank(String bankId, String bankName) {
    if (_verifiedBankIds.contains(bankId)) return true;
    final lowerName = bankName.toLowerCase();
    return _verifiedBankIds.any((id) =>
        lowerName.contains(id.toLowerCase()) ||
        id.toLowerCase().contains(lowerName));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const gold = Color(0xFFC9A96E);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Bank Favorites & Catalog',
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: gold,
          labelColor: gold,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          tabs: const [
            Tab(
              key: ValueKey('tab_my_favorites'),
              icon: Icon(Icons.star_rounded, size: 20),
              text: 'My Favorites',
            ),
            Tab(
              key: ValueKey('tab_bank_catalog'),
              icon: Icon(Icons.account_balance_outlined, size: 20),
              text: 'Bank Catalog',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
            ),
            child: Column(
              children: [
                // Search Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    key: const ValueKey('bank_search_text_field'),
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search banks by name or short code...',
                      prefixIcon: const Icon(Icons.search_rounded, color: gold),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: gold, width: 1.5),
                      ),
                    ),
                  ),
                ),

                // Tabs view
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Favorites
                      _buildFavoritesTab(isDark, gold),

                      // Tab 2: Catalog
                      _buildCatalogTab(isDark, gold),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesTab(bool isDark, Color gold) {
    return BlocBuilder<FavoriteBanksBloc, FavoriteBanksState>(
      builder: (context, state) {
        if (state is FavoriteBanksLoading) {
          return Center(child: CircularProgressIndicator(color: gold));
        }

        final favorites = state is FavoriteBanksLoaded
            ? state.favorites
            : <FavoriteBank>[];

        final filtered = favorites.where((f) {
          if (_searchQuery.isEmpty) return true;
          return f.bankName.toLowerCase().contains(_searchQuery) ||
              f.bankShortName.toLowerCase().contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) {
          if (_searchQuery.isNotEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No Matching Favorites',
                subtitle: 'No favorited banks match your search term.',
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EmptyState(
                    icon: Icons.star_border_rounded,
                    title: 'No Favorite Banks Yet',
                    subtitle:
                        'Star your frequently checked banks in the Catalog tab for one-tap rate comparisons and verified rate alerts.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    key: const ValueKey('browse_catalog_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text(
                      'Browse Bank Catalog',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: Responsive.screenPadding(context),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final favorite = filtered[index];
            final isVerified =
                _isVerifiedBank(favorite.bankId, favorite.bankName);
            return _buildBankCard(
              bankId: favorite.bankId,
              bankName: favorite.bankName,
              bankShortName: favorite.bankShortName,
              isFavorite: true,
              isVerified: isVerified,
              isDark: isDark,
              gold: gold,
            );
          },
        );
      },
    );
  }

  Widget _buildCatalogTab(bool isDark, Color gold) {
    if (_isLoadingCatalog) {
      return Center(child: CircularProgressIndicator(color: gold));
    }

    final filtered = _catalogBanks.where((b) {
      if (_searchQuery.isEmpty) return true;
      return b.name.toLowerCase().contains(_searchQuery) ||
          b.shortName.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No Banks Found',
          subtitle: 'No institutions in the catalog match your query.',
        ),
      );
    }

    return BlocBuilder<FavoriteBanksBloc, FavoriteBanksState>(
      builder: (context, state) {
        final favoriteIds = state is FavoriteBanksLoaded
            ? state.favoriteIds
            : <String>{};

        return ListView.separated(
          padding: Responsive.screenPadding(context),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final bank = filtered[index];
            final isFav = favoriteIds.contains(bank.id);
            final isVerified = _isVerifiedBank(bank.id, bank.name);
            return _buildBankCard(
              bankId: bank.id,
              bankName: bank.name,
              bankShortName: bank.shortName,
              isFavorite: isFav,
              isVerified: isVerified,
              isDark: isDark,
              gold: gold,
            );
          },
        );
      },
    );
  }

  Widget _buildBankCard({
    required String bankId,
    required String bankName,
    required String bankShortName,
    required bool isFavorite,
    required bool isVerified,
    required bool isDark,
    required Color gold,
  }) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '$bankName, ${isVerified ? "Verified Rates Available" : "Catalog Only"}',
      child: InkWell(
        key: ValueKey('bank_card_$bankId'),
        onTap: () {
          context.push('/bank/${Uri.encodeComponent(bankName)}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFavorite
                  ? gold.withValues(alpha: 0.35)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
              width: isFavorite ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Bank Icon / Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isVerified
                      ? gold.withValues(alpha: 0.15)
                      : (isDark ? Colors.white10 : Colors.black12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    bankShortName.isNotEmpty
                        ? (bankShortName.length <= 4
                            ? bankShortName
                            : bankShortName.substring(0, 3))
                        : 'BK',
                    style: TextStyle(
                      color: isVerified ? gold : theme.textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name and Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bankName,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? gold.withValues(alpha: 0.15)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVerified
                                    ? Icons.verified_rounded
                                    : Icons.info_outline_rounded,
                                size: 11,
                                color: isVerified
                                    ? gold
                                    : theme.textTheme.bodySmall?.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isVerified
                                    ? 'Verified Rates Available'
                                    : 'Catalog Only',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isVerified
                                      ? gold
                                      : theme.textTheme.bodySmall?.color,
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

              // Favorite Star Toggle Button
              Semantics(
                button: true,
                label: isFavorite
                    ? 'Remove $bankName from favorites'
                    : 'Add $bankName to favorites',
                child: IconButton(
                  key: ValueKey('favorite_toggle_$bankId'),
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFavorite ? gold : Colors.grey,
                    size: 26,
                  ),
                  tooltip:
                      isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  onPressed: () {
                    final fav = FavoriteBank(
                      bankId: bankId,
                      bankName: bankName,
                      bankShortName: bankShortName,
                      addedAt: DateTime.now(),
                    );
                    context
                        .read<FavoriteBanksBloc>()
                        .add(ToggleFavoriteBank(fav));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
