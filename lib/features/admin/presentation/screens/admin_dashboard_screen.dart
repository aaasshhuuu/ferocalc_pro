import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/models/admin_operational_metrics.dart';
import '../../data/models/staged_candidate.dart';
import '../../data/services/admin_api_service.dart';
import '../../data/services/admin_auth_service.dart';
import '../widgets/admin_status_badge.dart';
import '../widgets/operational_metrics_grid.dart';
import '../widgets/rate_review_queue_card.dart';
import 'candidate_review_screen.dart';

/// Main Admin Dashboard & Verified Rate Review Console screen.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    Key? key,
    this.initialTab = 0,
  }) : super(key: key);

  final int initialTab;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Search & Filter State
  String _selectedStatus = 'ALL';
  String _searchBank = '';
  final TextEditingController _searchController = TextEditingController();

  // Queue Pagination
  int _offset = 0;
  static const int _limit = 20;
  int _totalCandidates = 0;
  List<StagedCandidate> _candidates = [];

  // Loading & Error States
  bool _isLoadingQueue = false;
  bool _isLoadingMetrics = false;
  String? _queueError;

  // Operational Metrics
  AdminOperationalMetrics? _metrics;

  // Verified Rates Catalog (Tab 2)
  List<Map<String, dynamic>> _verifiedRates = [];
  bool _isLoadingVerifiedRates = false;
  String? _verifiedRatesError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _fetchMetrics(),
      _fetchCandidatesQueue(),
      _fetchVerifiedRates(),
    ]);
  }

  Future<void> _fetchMetrics() async {
    setState(() {
      _isLoadingMetrics = true;
    });

    try {
      final apiService = GetIt.instance<AdminApiService>();
      final metrics = await apiService.getOperationalMetrics();
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _isLoadingMetrics = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMetrics = false;
        });
      }
    }
  }

  Future<void> _fetchCandidatesQueue() async {
    setState(() {
      _isLoadingQueue = true;
      _queueError = null;
    });

    try {
      final apiService = GetIt.instance<AdminApiService>();
      final statusParam = _selectedStatus == 'ALL'
          ? null
          : _selectedStatus == 'ANOMALIES'
              ? null
              : _selectedStatus;

      final bool? hasAnomalies = _selectedStatus == 'ANOMALIES' ? true : null;

      final response = await apiService.getStagedCandidates(
        status: statusParam,
        bankCode: _searchBank.isNotEmpty ? _searchBank : null,
        hasAnomalies: hasAnomalies,
        limit: _limit,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          _candidates = response.candidates;
          _totalCandidates = response.total;
          _isLoadingQueue = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _queueError = e.toString().replaceAll('Exception: ', '');
          _isLoadingQueue = false;
        });
      }
    }
  }

  Future<void> _fetchVerifiedRates() async {
    setState(() {
      _isLoadingVerifiedRates = true;
      _verifiedRatesError = null;
    });

    try {
      final apiService = GetIt.instance<AdminApiService>();
      final rates = await apiService.getVerifiedRates(status: 'VERIFIED');
      if (mounted) {
        setState(() {
          _verifiedRates = rates;
          _isLoadingVerifiedRates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifiedRatesError = e.toString().replaceAll('Exception: ', '');
          _isLoadingVerifiedRates = false;
        });
      }
    }
  }

  void _onStatusFilterSelected(String status) {
    setState(() {
      _selectedStatus = status;
      _offset = 0; // reset pagination
    });
    _fetchCandidatesQueue();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchBank = query.trim();
      _offset = 0;
    });
    _fetchCandidatesQueue();
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Sign Out of Admin Console'),
        content: const Text('Are you sure you want to end your administrative review session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FeroColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = GetIt.instance<AdminAuthService>();
      await authService.logout();
      if (mounted) {
        context.go('/profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = GetIt.instance<AdminAuthService>();
    final session = authService.currentSession;
    final role = session?.role ?? 'ADMIN';

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Rate Review Console',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: FeroColors.gold),
            tooltip: 'Refresh Dashboard',
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            tooltip: 'Sign Out',
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: RefreshIndicator(
              color: FeroColors.gold,
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // User Session Bar
                  _buildSessionBar(role, session?.email ?? ''),
                  const SizedBox(height: 16),

                  // Operational Metrics Grid
                  OperationalMetricsGrid(
                    metrics: _metrics,
                    isLoading: _isLoadingMetrics,
                    selectedStatus: _selectedStatus,
                    onSelectStatus: _onStatusFilterSelected,
                  ),
                  const SizedBox(height: 20),

                  // Navigation Tabs
                  TabBar(
                    controller: _tabController,
                    indicatorColor: FeroColors.gold,
                    labelColor: FeroColors.gold,
                    unselectedLabelColor: Colors.grey,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.rate_review_outlined, size: 16),
                            const SizedBox(width: 8),
                            Text('Review Queue ($_totalCandidates)'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_outlined, size: 16),
                            const SizedBox(width: 8),
                            Text('Active Catalog (${_verifiedRates.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tab Content
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      if (_tabController.index == 0) {
                        return _buildQueueSection();
                      } else {
                        return _buildActiveCatalogSection();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionBar(String role, String email) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          AdminStatusBadge.forRole(role),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              email.isNotEmpty ? email : 'Authenticated Reviewer',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.verified_user, size: 14, color: FeroColors.verified),
          const SizedBox(width: 4),
          const Text(
            'Server Enforced',
            style: TextStyle(fontSize: 11, color: FeroColors.verified, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Filter controls
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by bank (e.g. SBI, HDFC)...',
                  prefixIcon: const Icon(Icons.search, size: 18, color: FeroColors.gold),
                  suffixIcon: _searchBank.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                onSubmitted: _onSearchChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filter chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL', 'All Candidates'),
              const SizedBox(width: 6),
              _buildFilterChip('IN_REVIEW', 'Awaiting Review'),
              const SizedBox(width: 6),
              _buildFilterChip('DRAFT', 'Drafts'),
              const SizedBox(width: 6),
              _buildFilterChip('PROMOTED', 'Promoted'),
              const SizedBox(width: 6),
              _buildFilterChip('REJECTED', 'Rejected'),
              const SizedBox(width: 6),
              _buildFilterChip('ANOMALIES', 'Anomalies'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Queue Results List
        if (_isLoadingQueue) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(FeroColors.gold),
              ),
            ),
          ),
        ] else if (_queueError != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FeroColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FeroColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 36, color: FeroColors.error),
                const SizedBox(height: 10),
                Text(
                  'Failed to load staged candidates',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _queueError!,
                  style: const TextStyle(color: FeroColors.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: FeroColors.gold, foregroundColor: Colors.black),
                  onPressed: _fetchCandidatesQueue,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry Queue Query'),
                ),
              ],
            ),
          ),
        ] else if (_candidates.isEmpty) ...[
          EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No Staged Candidates Found',
            subtitle: _selectedStatus == 'ALL'
                ? 'No rate candidates are currently staged in the database.'
                : 'No candidates matched the "$_selectedStatus" filter.',
            actionLabel: 'Reset Filters',
            onAction: () {
              _searchController.clear();
              _searchBank = '';
              _onStatusFilterSelected('ALL');
            },
          ),
        ] else ...[
          // Candidate Cards
          ...List.generate(_candidates.length, (index) {
            final candidate = _candidates[index];
            return RateReviewQueueCard(
              candidate: candidate,
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CandidateReviewScreen(candidate: candidate),
                  ),
                );
                // Refresh queue and metrics after returning
                _fetchCandidatesQueue();
                _fetchMetrics();
              },
            );
          }),

          // Pagination Controls
          _buildPaginationControls(),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String statusKey, String label) {
    final isSelected = _selectedStatus == statusKey;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Colors.black : Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: FeroColors.gold,
      checkmarkColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onSelected: (_) => _onStatusFilterSelected(statusKey),
    );
  }

  Widget _buildPaginationControls() {
    final hasPrevious = _offset > 0;
    final hasNext = (_offset + _limit) < _totalCandidates;
    final currentStart = _totalCandidates == 0 ? 0 : _offset + 1;
    final currentEnd = (_offset + _limit) > _totalCandidates ? _totalCandidates : _offset + _limit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $currentStart–$currentEnd of $_totalCandidates',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: hasPrevious
                    ? () {
                        setState(() {
                          _offset = (_offset - _limit).clamp(0, _totalCandidates);
                        });
                        _fetchCandidatesQueue();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: hasNext
                    ? () {
                        setState(() {
                          _offset += _limit;
                        });
                        _fetchCandidatesQueue();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCatalogSection() {
    if (_isLoadingVerifiedRates) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(FeroColors.gold),
          ),
        ),
      );
    }

    if (_verifiedRatesError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FeroColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('Error loading verified catalog: $_verifiedRatesError',
            style: const TextStyle(color: FeroColors.error, fontSize: 13),),
      );
    }

    if (_verifiedRates.isEmpty) {
      return const EmptyState(
        icon: Icons.verified_user_outlined,
        title: 'No Active Verified Rates',
        subtitle: 'Promoted candidate rates will appear here in the published active catalog.',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _verifiedRates.length,
      itemBuilder: (context, index) {
        final rate = _verifiedRates[index];
        final bankInfo = rate['banks'] as Map<String, dynamic>?;
        final bankName = bankInfo?['short_name'] ?? bankInfo?['name'] ?? rate['bank_id'] ?? 'BANK';
        final interestRate = (rate['interest_rate'] as num?)?.toDouble() ?? 0.0;
        final customerType = rate['customer_type']?.toString() ?? 'REGULAR';
        final tenureDomain = rate['tenure_domain']?.toString() ?? 'DAYS';
        final tenureText = rate['source_tenure_text'] ??
            (rate['min_tenure_days'] != null ? '${rate['min_tenure_days']}–${rate['max_tenure_days']} days' : 'N/A');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FeroColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  bankName.toString(),
                  style: const TextStyle(color: FeroColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$tenureText ($tenureDomain)',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer: $customerType | ID: ${rate['id']}',
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '${interestRate.toStringAsFixed(2)}%',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: FeroColors.verified),
              ),
            ],
          ),
        );
      },
    );
  }
}
