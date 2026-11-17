import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../injection_container.dart' as di;
import '../../data/models/calculation_history_entry.dart';
import '../bloc/calculation_history_bloc.dart';
import '../widgets/calculation_history_card.dart';

enum HistorySortOption {
  recentlySaved('Recently Saved'),
  recentlyUpdated('Recently Updated'),
  nameAsc('Name (A-Z)');

  const HistorySortOption(this.label);
  final String label;
}

class CalculationHistoryScreen extends StatefulWidget {
  const CalculationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CalculationHistoryScreen> createState() =>
      _CalculationHistoryScreenState();
}

class _CalculationHistoryScreenState extends State<CalculationHistoryScreen> {
  late final CalculationHistoryBloc _bloc;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  HistorySortOption _sortOption = HistorySortOption.recentlySaved;

  final List<String> _categories = [
    'All',
    'Loans',
    'Investments',
    'Deposits',
    'Tax',
    'Retirement',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _bloc = di.sl<CalculationHistoryBloc>()..add(const LoadCalculationHistory());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bloc.close();
    super.dispose();
  }

  String _getCalculatorRoute(String calculatorId) {
    switch (calculatorId) {
      case 'emi':
        return '/calculator/emi';
      case 'loan_amount':
        return '/calculator/loan_amount';
      case 'loan_term':
        return '/calculator/loan_term';
      case 'interest_rate':
        return '/calculator/interest_rate';
      case 'home_loan_eligibility':
        return '/calculator/home_loan_eligibility';
      case 'personal_loan_eligibility':
        return '/calculator/personal_loan_eligibility';
      case 'credit_card_emi':
        return '/calculator/credit_card_emi';
      case 'fd':
        return '/calculator/fd';
      case 'rd':
        return '/calculator/rd';
      case 'savings':
        return '/calculator/savings';
      case 'ppf':
        return '/calculator/ppf';
      case 'sip':
        return '/calculator/sip';
      case 'swp':
        return '/calculator/swp';
      case 'lumpsum':
        return '/calculator/lumpsum';
      case 'cagr':
        return '/calculator/cagr';
      case 'stock_return':
        return '/calculator/stock_return';
      case 'dividend_yield':
        return '/calculator/dividend_yield';
      case 'nps':
        return '/calculator/nps';
      case 'epf':
        return '/calculator/epf';
      case 'income_tax':
        return '/calculator/income_tax';
      case 'gst':
        return '/calculator/gst';
      case 'retirement':
      case 'retirement_planner':
        return '/calculator/retirement';
      case 'goal':
      case 'goal_planner':
        return '/calculator/goal';
      case 'education':
      case 'education_planner':
        return '/calculator/education';
      case 'inflation':
        return '/calculator/inflation';
      case 'sukanya':
      case 'sukanya_samriddhi':
        return '/calculator/sukanya';
      case 'simple_interest':
        return '/calculator/simple_interest';
      case 'compound_interest':
        return '/calculator/compound_interest';
      default:
        return '/calculators';
    }
  }

  void _reopenInCalculator(CalculationHistoryEntry entry) {
    final route = _getCalculatorRoute(entry.calculatorId);
    context.push(route, extra: entry);
  }

  void _confirmClearAll(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
          'Are you sure you want to remove all saved calculations? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _bloc.add(const ClearAllCalculationHistory());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Calculation history cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(CalculationHistoryEntry entry) {
    final controller = TextEditingController(text: entry.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Calculation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Calculation Name',
            hintText: 'e.g. Dream House Loan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                _bloc.add(RenameCalculationEntry(entry.id, newName));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Renamed to "$newName"')),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFFC9A96E), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEntry(CalculationHistoryEntry entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Calculation?'),
        content: Text('Are you sure you want to remove "${entry.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _bloc.add(DeleteCalculationEntry(entry.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${entry.title} removed')),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _duplicateEntry(CalculationHistoryEntry entry) {
    _bloc.add(DuplicateCalculationEntry(entry.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Duplicated "${entry.title}"')),
    );
  }

  List<CalculationHistoryEntry> _filterAndSortEntries(List<CalculationHistoryEntry> entries) {
    final filtered = entries.where((entry) {
      // Category filter
      if (_selectedCategory != 'All') {
        final cat = entry.category?.toLowerCase() ?? 'general';
        if (_selectedCategory.toLowerCase() != cat) {
          return false;
        }
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = entry.title.toLowerCase().contains(query);
        final matchesCalc = entry.calculatorName.toLowerCase().contains(query);
        final matchesInputs = entry.inputs.values.any((String v) => v.toLowerCase().contains(query));
        final matchesResults = entry.results.values.any((String v) => v.toLowerCase().contains(query));
        if (!matchesName && !matchesCalc && !matchesInputs && !matchesResults) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort
    switch (_sortOption) {
      case HistorySortOption.recentlySaved:
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case HistorySortOption.recentlyUpdated:
        filtered.sort((a, b) => b.effectiveUpdatedAt.compareTo(a.effectiveUpdatedAt));
        break;
      case HistorySortOption.nameAsc:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Calculation History',
          actions: [
            BlocBuilder<CalculationHistoryBloc, CalculationHistoryState>(
              builder: (context, state) {
                if (state is CalculationHistoryLoaded && state.entries.isNotEmpty) {
                  return IconButton(
                    key: const ValueKey('clear_all_history_button'),
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                    tooltip: 'Clear All',
                    onPressed: () => _confirmClearAll(context),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
            child: BlocConsumer<CalculationHistoryBloc, CalculationHistoryState>(
              listener: (context, state) {
                if (state is CalculationHistoryError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${state.message}')),
                  );
                }
              },
              builder: (context, state) {
                if (state is CalculationHistoryLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFC9A96E)),
                  );
                }

                if (state is CalculationHistoryLoaded) {
                  if (state.entries.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final filteredEntries = _filterAndSortEntries(state.entries);

                  return Column(
                    children: [
                      // Search and Controls Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          children: [
                            // Search Field
                            TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search saved calculations...',
                                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFFC9A96E)),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Theme.of(context).cardColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Categories and Sort row
                            Row(
                              children: [
                                // Categories scrollable
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: _categories.map((cat) {
                                        final isSelected = _selectedCategory == cat;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: FilterChip(
                                            label: Text(
                                              cat,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color: isSelected ? Colors.black : Colors.white70,
                                              ),
                                            ),
                                            selected: isSelected,
                                            selectedColor: const Color(0xFFC9A96E),
                                            backgroundColor: Theme.of(context).cardColor,
                                            onSelected: (_) {
                                              setState(() => _selectedCategory = cat);
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Sort selector button
                                PopupMenuButton<HistorySortOption>(
                                  icon: const Icon(Icons.sort, color: Color(0xFFC9A96E)),
                                  tooltip: 'Sort Calculations',
                                  initialValue: _sortOption,
                                  onSelected: (opt) {
                                    setState(() => _sortOption = opt);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: HistorySortOption.recentlySaved,
                                      child: Text('Recently Saved'),
                                    ),
                                    const PopupMenuItem(
                                      value: HistorySortOption.recentlyUpdated,
                                      child: Text('Recently Updated'),
                                    ),
                                    const PopupMenuItem(
                                      value: HistorySortOption.nameAsc,
                                      child: Text('Name (A-Z)'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // List view
                      Expanded(
                        child: filteredEntries.isEmpty
                            ? _buildNoResultsState(context)
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: Responsive.screenPadding(context),
                                itemCount: filteredEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = filteredEntries[index];
                                  return Dismissible(
                                    key: ValueKey('history_item_${entry.id}'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    onDismissed: (_) {
                                      _bloc.add(DeleteCalculationEntry(entry.id));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${entry.title} removed'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: CalculationHistoryCard(
                                      entry: entry,
                                      onTap: () async {
                                        await context.push('/history/detail', extra: entry);
                                        _bloc.add(const LoadCalculationHistory());
                                      },
                                      onReopen: () => _reopenInCalculator(entry),
                                      onRename: () => _showRenameDialog(entry),
                                      onDuplicate: () => _duplicateEntry(entry),
                                      onDelete: () => _confirmDeleteEntry(entry),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFC9A96E).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_toggle_off,
              color: Color(0xFFC9A96E),
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Calculation History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Completed calculations will automatically appear here for later viewing, management, and export.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              key: const ValueKey('start_calculating_button'),
              text: 'Start Calculating',
              onPressed: () {
                context.go('/calculators');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: theme.textTheme.bodySmall?.color ?? Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No Matching Calculations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search query or category filters.',
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedCategory = 'All';
              });
            },
            child: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }
}
