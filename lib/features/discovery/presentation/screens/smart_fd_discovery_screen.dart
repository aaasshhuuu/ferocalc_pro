import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/bank.dart';
import '../../../../core/models/discovery_models.dart';
import '../../../../core/models/verified_fd_rate.dart';
import '../../../../core/services/verified_rate_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/financial_math.dart' hide CompoundingFrequency;
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import 'advanced_fd_comparison_screen.dart';

class SmartFdDiscoveryScreen extends StatefulWidget {
  const SmartFdDiscoveryScreen({
    Key? key,
    this.initialDepositAmount,
    this.initialTenureYears,
    this.initialIsSeniorCitizen,
    this.initialBankId,
  }) : super(key: key);

  final double? initialDepositAmount;
  final int? initialTenureYears;
  final bool? initialIsSeniorCitizen;
  final String? initialBankId;

  @override
  State<SmartFdDiscoveryScreen> createState() => _SmartFdDiscoveryScreenState();
}

class _SmartFdDiscoveryScreenState extends State<SmartFdDiscoveryScreen> {
  static const Color gold = Color(0xFFC9A96E);
  static const Color emerald = Color(0xFF10B981);
  static const Color cyan = Color(0xFF38BDF8);

  late TextEditingController _amountController;
  late TextEditingController _tenureController;

  late FdDiscoveryCriteria _criteria;
  FdSortOption _sortOption = FdSortOption.maturityAmount;

  List<VerifiedFdRate> _allVerifiedRates = [];
  List<Bank> _activeBanks = [];
  List<FdDiscoveryMatch> _matches = [];

  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _selectedComparisonRateIds = {};

  final List<double> _quickAmounts = [25000, 100000, 200000, 500000, 1000000];

  final List<Map<String, dynamic>> _quickTenures = [
    {'label': '91 Days', 'unit': TenureUnit.days, 'value': 91},
    {'label': '180 Days', 'unit': TenureUnit.days, 'value': 180},
    {'label': '1 Year', 'unit': TenureUnit.years, 'value': 1},
    {'label': '2 Years', 'unit': TenureUnit.years, 'value': 2},
    {'label': '3 Years', 'unit': TenureUnit.years, 'value': 3},
    {'label': '5 Years', 'unit': TenureUnit.years, 'value': 5},
  ];

  final List<String> _bankTypes = ['All', 'Public', 'Private', 'Small Finance'];

  @override
  void initState() {
    super.initState();
    final deposit = widget.initialDepositAmount ?? 100000.0;
    final tenureVal = widget.initialTenureYears ?? 1;
    final isSenior = widget.initialIsSeniorCitizen ?? false;

    _amountController = TextEditingController(text: deposit.toInt().toString());
    _tenureController = TextEditingController(text: tenureVal.toString());

    _criteria = FdDiscoveryCriteria(
      depositAmount: deposit,
      tenureUnit: TenureUnit.years,
      tenureValue: tenureVal,
      customerCategory: isSenior ? CustomerCategory.seniorCitizen : CustomerCategory.regular,
      callablePreference: CallablePreference.any,
      selectedBankId: widget.initialBankId,
      selectedBankType: 'All',
    );

    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        VerifiedRateService.fetchAll(
          customerType: _criteria.customerCategory == CustomerCategory.seniorCitizen
              ? 'SENIOR_CITIZEN'
              : 'REGULAR',
          isCallable: null,
        ),
        VerifiedRateService.fetchBanks(),
      ]);

      final rateResponse = results[0] as VerifiedRatesResponse;
      final banksList = results[1] as List<Bank>;

      if (mounted) {
        setState(() {
          _allVerifiedRates = rateResponse.rates;
          _activeBanks = banksList;
          _isLoading = false;
          if (rateResponse.hasError && rateResponse.rates.isEmpty) {
            _errorMessage = rateResponse.errorMessage ??
                'Verified rate service is temporarily unavailable.';
          } else {
            _runMatching();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load verified rates. Please check your network connection.';
        });
      }
    }
  }

  void _runMatching() {
    final rawMatches = FdDiscoveryEngine.findMatches(
      rates: _allVerifiedRates,
      criteria: _criteria,
      banks: _activeBanks,
    );

    final sorted = FdDiscoveryEngine.sortMatches(rawMatches, _sortOption);

    setState(() {
      _matches = sorted;
      // Retain comparison selections that are still in matching results
      final validIds = _matches.map((m) => m.rate.id).toSet();
      _selectedComparisonRateIds.removeWhere((id) => !validIds.contains(id));
    });
  }

  void _updateCriteria(FdDiscoveryCriteria newCriteria) {
    setState(() {
      _criteria = newCriteria;
    });
    _runMatching();
  }

  void _toggleComparison(FdDiscoveryMatch match) {
    setState(() {
      if (_selectedComparisonRateIds.contains(match.rate.id)) {
        _selectedComparisonRateIds.remove(match.rate.id);
      } else {
        if (_selectedComparisonRateIds.length >= 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can compare a maximum of 4 FD options at once.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedComparisonRateIds.add(match.rate.id);
      }
    });
  }

  void _openComparisonSheet() {
    final selectedMatches = _matches
        .where((m) => _selectedComparisonRateIds.contains(m.rate.id))
        .toList();

    if (selectedMatches.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 2 FD options to compare side-by-side.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdvancedFdComparisonScreen(
          selectedMatches: selectedMatches,
          criteria: _criteria,
        ),
      ),
    );
  }

  void _navigateToCalculator(FdDiscoveryMatch match) {
    int years = 0;
    int months = 0;
    int days = 0;

    switch (_criteria.tenureUnit) {
      case TenureUnit.days:
        days = _criteria.tenureValue;
        break;
      case TenureUnit.months:
        years = _criteria.tenureValue ~/ 12;
        months = _criteria.tenureValue % 12;
        break;
      case TenureUnit.years:
        years = _criteria.tenureValue;
        break;
    }

    context.push(
      '/calculator/fd',
      extra: {
        'principal': _criteria.depositAmount,
        'interestRate': match.interestRate,
        'years': years,
        'months': months,
        'days': days,
        'isSeniorCitizen': _criteria.customerCategory == CustomerCategory.seniorCitizen,
        'bankName': match.bankName,
        'sourceUrl': match.sourceUrl,
        'verifiedAt': match.verifiedAt?.toIso8601String(),
        'compoundingFrequency': match.compoundingFrequency.displayLabel,
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF091422) : Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Best for Me FD Finder',
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: gold),
            tooltip: 'Data Trust Center',
            onPressed: () => context.push('/trust-center'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh verified rates',
            onPressed: _loadData,
          ),
        ],
      ),
      bottomNavigationBar: _selectedComparisonRateIds.isNotEmpty
          ? _buildComparisonBottomBar(context, isDark)
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: Responsive.screenPadding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeaderBanner(context, isDark),
                        const SizedBox(height: 16),
                        _buildCriteriaCard(context, isDark),
                        const SizedBox(height: 20),
                        _buildResultsHeader(context, isDark),
                      ],
                    ),
                  ),
                ),
                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: gold, strokeWidth: 2.5),
                    ),
                  )
                else if (_errorMessage != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildErrorState(context, isDark),
                  )
                else if (_matches.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context, isDark),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.screenPadding(context).left,
                      0,
                      Responsive.screenPadding(context).right,
                      80,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final match = _matches[index];
                          return _buildMatchCard(context, match, isDark, index);
                        },
                        childCount: _matches.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF132235), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: gold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Smart FD Discovery',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: emerald.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 10, color: emerald),
                          SizedBox(width: 3),
                          Text(
                            '100% VERIFIED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: emerald,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Find official bank fixed deposits mathematically matching your exact deposit amount, tenure, and customer category.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaCard(BuildContext context, bool isDark) {
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Investment Criteria',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _criteria = const FdDiscoveryCriteria();
                    _amountController.text = '100000';
                    _tenureController.text = '1';
                  });
                  _runMatching();
                },
                child: const Text(
                  'Reset',
                  style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // 1. Deposit Amount
          Text(
            'Deposit Amount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.bold),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              filled: true,
              fillColor: isDark ? const Color(0xFF132235) : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: gold, width: 1.5),
              ),
            ),
            onChanged: (val) {
              final parsed = double.tryParse(val) ?? 0;
              if (parsed > 0) {
                _updateCriteria(_criteria.copyWith(depositAmount: parsed));
              }
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickAmounts.map((amt) {
                final isSelected = (_criteria.depositAmount - amt).abs() < 1;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(
                      FinancialMath.formatCurrencyRounded(amt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? gold : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    backgroundColor: isSelected
                        ? gold.withValues(alpha: 0.2)
                        : (isDark ? const Color(0xFF132235) : Colors.grey[200]),
                    side: BorderSide(
                      color: isSelected ? gold : Colors.transparent,
                    ),
                    onPressed: () {
                      _amountController.text = amt.toInt().toString();
                      _updateCriteria(_criteria.copyWith(depositAmount: amt));
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Investment Tenure & Unit
          Text(
            'Investment Tenure',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _tenureController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF132235) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: gold, width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 0;
                    if (parsed > 0) {
                      _updateCriteria(_criteria.copyWith(tenureValue: parsed));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: SegmentedButton<TenureUnit>(
                  segments: const [
                    ButtonSegment(value: TenureUnit.days, label: Text('Days', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: TenureUnit.months, label: Text('Months', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: TenureUnit.years, label: Text('Years', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {_criteria.tenureUnit},
                  onSelectionChanged: (set) {
                    _updateCriteria(_criteria.copyWith(tenureUnit: set.first));
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickTenures.map((item) {
                final isSelected = _criteria.tenureUnit == item['unit'] &&
                    _criteria.tenureValue == item['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? gold : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    backgroundColor: isSelected
                        ? gold.withValues(alpha: 0.2)
                        : (isDark ? const Color(0xFF132235) : Colors.grey[200]),
                    side: BorderSide(
                      color: isSelected ? gold : Colors.transparent,
                    ),
                    onPressed: () {
                      final unit = item['unit'] as TenureUnit;
                      final val = item['value'] as int;
                      _tenureController.text = val.toString();
                      _updateCriteria(
                        _criteria.copyWith(tenureUnit: unit, tenureValue: val),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Customer Category & Liquidity Preference
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Category',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<CustomerCategory>(
                      segments: const [
                        ButtonSegment(value: CustomerCategory.regular, label: Text('Regular', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: CustomerCategory.seniorCitizen, label: Text('Senior Citizen', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {_criteria.customerCategory},
                      onSelectionChanged: (set) {
                        _updateCriteria(_criteria.copyWith(customerCategory: set.first));
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Product Type (Callable / Non-Callable) & Bank Filter
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Withdrawal Flexibility',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF132235) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CallablePreference>(
                          isExpanded: true,
                          value: _criteria.callablePreference,
                          dropdownColor: isDark ? const Color(0xFF132235) : Colors.white,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: CallablePreference.any,
                              child: Text('Any (All Products)'),
                            ),
                            DropdownMenuItem(
                              value: CallablePreference.callableOnly,
                              child: Text('Callable (Exit Allowed)'),
                            ),
                            DropdownMenuItem(
                              value: CallablePreference.nonCallableOnly,
                              child: Text('Non-Callable (Locked)'),
                            ),
                          ],
                          onChanged: (pref) {
                            if (pref != null) {
                              _updateCriteria(_criteria.copyWith(callablePreference: pref));
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bank Selection',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF132235) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _criteria.selectedBankId ?? 'all',
                          dropdownColor: isDark ? const Color(0xFF132235) : Colors.white,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Verified Banks'),
                            ),
                            ..._activeBanks.map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                                ),),
                          ],
                          onChanged: (bankId) {
                            _updateCriteria(_criteria.copyWith(
                              selectedBankId: bankId == 'all' ? null : bankId,
                            ),);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Bank Type Chips
          Row(
            children: [
              Text(
                'Sector: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _bankTypes.map((type) {
                      final isSelected = _criteria.selectedBankType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(type, style: const TextStyle(fontSize: 10)),
                          selected: isSelected,
                          selectedColor: gold.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? gold : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            _updateCriteria(_criteria.copyWith(selectedBankType: type));
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Matching options for your criteria (${_matches.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Based on your selected criteria • Standard quarterly compounding',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132235) : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<FdSortOption>(
              value: _sortOption,
              dropdownColor: isDark ? const Color(0xFF132235) : Colors.white,
              icon: const Icon(Icons.sort, size: 16, color: gold),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              items: FdSortOption.values.map((opt) {
                return DropdownMenuItem(
                  value: opt,
                  child: Text(opt.label),
                );
              }).toList(),
              onChanged: (opt) {
                if (opt != null) {
                  setState(() {
                    _sortOption = opt;
                    _matches = FdDiscoveryEngine.sortMatches(_matches, _sortOption);
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(
    BuildContext context,
    FdDiscoveryMatch match,
    bool isDark,
    int index,
  ) {
    final isSelectedForCompare = _selectedComparisonRateIds.contains(match.rate.id);
    final bank = _activeBanks.firstWhere(
      (b) => b.id == match.bankId,
      orElse: () => match.rate.toBank(),
    );

    return Semantics(
      container: true,
      label: '${match.bankName}, ${match.interestRate.toStringAsFixed(2)} percent per annum, estimated maturity ${FinancialMath.formatCurrency(match.estimatedMaturity)}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132235) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelectedForCompare
              ? cyan
              : (index == 0 ? gold.withValues(alpha: 0.6) : (isDark ? Colors.white12 : Colors.black12)),
          width: isSelectedForCompare || index == 0 ? 1.5 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Bank Info + Badges + Compare Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: gold.withValues(alpha: 0.15),
                  child: Text(
                    match.bankShortName.isNotEmpty
                        ? match.bankShortName.substring(0, match.bankShortName.length >= 2 ? 2 : 1)
                        : 'FD',
                    style: const TextStyle(
                      color: gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              match.bankName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 14, color: emerald),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            bank.typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          Text(
                            match.isCallable ? 'Callable (Exit allowed)' : 'Non-Callable (Locked)',
                            style: TextStyle(
                              fontSize: 10,
                              color: match.isCallable ? cyan : Colors.orangeAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Interest Rate Banner
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${match.interestRate.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: gold,
                      ),
                    ),
                    Text(
                      'p.a.',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Middle Box: Estimated Returns Breakdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1A28) : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Maturity',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FinancialMath.formatCurrency(match.estimatedMaturity),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 28,
                    width: 1,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Interest',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+${FinancialMath.formatCurrency(match.estimatedInterest)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Matching Slab & Provenance Metadata
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Matching Slab: ${match.matchingTenureText}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.layers_outlined, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Deposit Limits: ${match.depositRangeLabel}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                if (match.verifiedAt != null)
                  Text(
                    'Verified ${DateFormatter.formatRelative(match.verifiedAt!)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),

            // Actions: Official Source Link + Add to Compare + Calculate Returns
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (match.sourceUrl != null && match.sourceUrl!.isNotEmpty)
                  InkWell(
                    onTap: () => _launchUrl(match.sourceUrl!),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new, size: 12, color: gold),
                        SizedBox(width: 4),
                        Text(
                          'Official Source',
                          style: TextStyle(
                            fontSize: 11,
                            color: gold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add to compare button / checkbox
                    InkWell(
                      onTap: () => _toggleComparison(match),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelectedForCompare
                              ? cyan.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelectedForCompare
                                ? cyan
                                : (isDark ? Colors.white24 : Colors.black26),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelectedForCompare
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 14,
                              color: isSelectedForCompare
                                  ? cyan
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isSelectedForCompare ? 'Compared' : 'Compare',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelectedForCompare ? FontWeight.bold : FontWeight.normal,
                                color: isSelectedForCompare
                                    ? cyan
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Calculate Returns button
                    ElevatedButton.icon(
                      onPressed: () => _navigateToCalculator(match),
                      icon: const Icon(Icons.calculate_outlined, size: 14),
                      label: const Text('Calculate Returns', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),);
  }

  Widget _buildComparisonBottomBar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A28) : Colors.white,
        border: Border(
          top: BorderSide(color: cyan.withValues(alpha: 0.4)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cyan.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.compare_arrows_rounded, color: cyan, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_selectedComparisonRateIds.length} of 4 options selected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  _selectedComparisonRateIds.length < 2
                      ? 'Select 1 more option to compare'
                      : 'Compare like-for-like with identical inputs',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _selectedComparisonRateIds.length >= 2 ? _openComparisonSheet : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: cyan,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Compare Side-by-Side', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 54, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              'No verified fixed deposits match your exact criteria.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try widening your deposit amount, choosing a standard tenure (e.g. 1 Year), or setting bank selection to "All Verified Banks".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _criteria = const FdDiscoveryCriteria();
                      _amountController.text = '100000';
                      _tenureController.text = '1';
                    });
                    _runMatching();
                  },
                  child: const Text('Reset Criteria', style: TextStyle(color: gold)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => context.push('/trust-center'),
                  icon: const Icon(Icons.shield_outlined, size: 14),
                  label: const Text('View Bank Coverage', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF132235),
                    foregroundColor: gold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Could not retrieve verified rates.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
