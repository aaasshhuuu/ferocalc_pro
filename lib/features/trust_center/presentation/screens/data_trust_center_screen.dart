import 'package:flutter/material.dart';
import '../../../../core/models/bank.dart';
import '../../../../core/models/data_trust_models.dart';
import '../../../../core/models/verified_fd_rate.dart';
import '../../../../core/services/verified_rate_service.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../widgets/data_coverage_section.dart';
import '../widgets/rate_freshness_section.dart';
import '../widgets/source_transparency_section.dart';
import '../widgets/verification_process_section.dart';
import '../widgets/verified_rate_history_section.dart';

class DataTrustCenterScreen extends StatefulWidget {
  const DataTrustCenterScreen({
    Key? key,
    this.initialTab = 0,
    this.initialBankId,
  }) : super(key: key);

  final int initialTab;
  final String? initialBankId;

  @override
  State<DataTrustCenterScreen> createState() => _DataTrustCenterScreenState();
}

class _DataTrustCenterScreenState extends State<DataTrustCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingAll = true;
  String? _globalError;

  DataCoverageMetrics? _coverageMetrics;
  RateFreshnessResponse? _freshnessResponse;
  List<VerifiedFdRate> _verifiedRates = [];
  List<Bank> _banks = [];
  Bank? _selectedBankForHistory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
    _loadAllTrustData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTrustData() async {
    setState(() {
      _isLoadingAll = true;
      _globalError = null;
    });

    try {
      final freshness = await VerifiedRateService.fetchFreshness();
      final coverage = await VerifiedRateService.fetchCoverageMetrics(freshnessList: freshness.sources);
      final ratesRes = await VerifiedRateService.fetchAll(isCallable: null);

      if (mounted) {
        setState(() {
          _coverageMetrics = coverage;
          _freshnessResponse = freshness;
          _verifiedRates = ratesRes.rates;
          _banks = coverage.verifiedBanks;

          if (widget.initialBankId != null && _banks.isNotEmpty) {
            _selectedBankForHistory = _banks.firstWhere(
              (b) => b.id == widget.initialBankId,
              orElse: () => _banks.first,
            );
          } else if (_banks.isNotEmpty) {
            _selectedBankForHistory = _banks.first;
          }

          _isLoadingAll = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAll = false;
          _globalError = 'Failed to load Trust Center data: $e';
        });
      }
    }
  }

  Future<void> _refreshFreshnessOnly() async {
    final freshness = await VerifiedRateService.fetchFreshness();
    if (mounted) {
      setState(() {
        _freshnessResponse = freshness;
      });
    }
  }

  void _onSelectBankForHistory(Bank bank) {
    setState(() {
      _selectedBankForHistory = bank;
    });
    _tabController.animateTo(2); // Switch to Rate History tab
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC9A96E);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1118),
      appBar: CustomAppBar(
        title: 'Data Trust Center',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: gold),
            tooltip: 'Refresh all trust data',
            onPressed: _isLoadingAll ? null : _loadAllTrustData,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Trust Banner Header
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF132235),
                        const Color(0xFF0F172A).withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gold.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user, color: gold, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consumer Rate Verification & Trust',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Complete transparency into data coverage, ingestion freshness, and verified rate history.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white70,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Navigation Tabs
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: gold,
                    indicatorWeight: 3,
                    labelColor: gold,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: const TextStyle(fontSize: 12.5),
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      Tab(text: 'Coverage'),
                      Tab(text: 'Freshness'),
                      Tab(text: 'History'),
                      Tab(text: 'Process'),
                      Tab(text: 'Sources'),
                    ],
                  ),
                ),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // 0: Coverage
                      RefreshIndicator(
                        onRefresh: _loadAllTrustData,
                        color: gold,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: DataCoverageSection(
                            metrics: _coverageMetrics,
                            isLoading: _isLoadingAll,
                            errorMessage: _globalError,
                            onRetry: _loadAllTrustData,
                            onSelectBankForHistory: _onSelectBankForHistory,
                          ),
                        ),
                      ),

                      // 1: Freshness
                      RefreshIndicator(
                        onRefresh: _refreshFreshnessOnly,
                        color: gold,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: RateFreshnessSection(
                            freshnessResponse: _freshnessResponse,
                            isLoading: _isLoadingAll,
                            errorMessage: _globalError,
                            onRefresh: _refreshFreshnessOnly,
                          ),
                        ),
                      ),

                      // 2: History
                      RefreshIndicator(
                        onRefresh: _loadAllTrustData,
                        color: gold,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: VerifiedRateHistorySection(
                            banks: _banks,
                            initialBank: _selectedBankForHistory,
                          ),
                        ),
                      ),

                      // 3: Process
                      const SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: VerificationProcessSection(),
                      ),

                      // 4: Sources
                      RefreshIndicator(
                        onRefresh: _loadAllTrustData,
                        color: gold,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: SourceTransparencySection(
                            verifiedRates: _verifiedRates,
                            freshnessList: _freshnessResponse?.sources ?? [],
                            isLoading: _isLoadingAll,
                          ),
                        ),
                      ),
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
}
