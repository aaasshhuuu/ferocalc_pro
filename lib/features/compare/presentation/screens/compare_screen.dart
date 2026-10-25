import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/bank_rate_repository.dart';
import '../../../../core/models/bank.dart';
import '../../../../core/models/fd_rate.dart';
import '../../../../core/models/verified_fd_rate.dart';
import '../../../../core/services/rate_display_config.dart';
import '../../../../core/services/verified_rate_service.dart';
import '../../../../core/utils/financial_math.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/fd_rate_card.dart';
import '../../../../core/widgets/official_rates_notice_card.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../core/widgets/verified_rate_badge.dart';

class CompareScreen extends StatefulWidget {
  final String? initialSource;

  const CompareScreen({Key? key, this.initialSource}) : super(key: key);

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _selectedSource = 'all'; // 'all' (Unverified Reference) or 'verified' (Official Verified)
  List<VerifiedFdRate> _verifiedRates = [];
  bool _isLoadingVerified = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSource == 'verified') {
      _selectedSource = 'verified';
    }
    _loadVerifiedRates();
  }

  Future<void> _loadVerifiedRates() async {
    setState(() => _isLoadingVerified = true);
    try {
      final res = await VerifiedRateService.fetchAll(
        customerType: _customerType == CustomerType.seniorCitizen ? 'SENIOR_CITIZEN' : 'REGULAR',
        tenureDays: _tenureDomain == TenureDomain.days ? _tenureDays : null,
        years: _tenureDomain == TenureDomain.calendar ? _calYears : null,
        months: _tenureDomain == TenureDomain.calendar ? _calMonths : null,
        daysCal: _tenureDomain == TenureDomain.calendar ? _calDays : null,
        depositAmount: _depositAmount,
        isCallable: null,
      );
      if (mounted) {
        setState(() {
          _verifiedRates = res.rates;
          _isLoadingVerified = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVerified = false);
    }
  }

  // Filter state
  TenureDomain _tenureDomain = TenureDomain.days;
  int _tenureDays = 365;
  int _calYears = 1;
  int _calMonths = 0;
  int _calDays = 0;
  String? _calendarValidationError;

  static const List<Map<String, dynamic>> _calendarPresets = [
    {'label': '6 Months', 'years': 0, 'months': 6, 'days': 0},
    {'label': '1 Year',   'years': 1, 'months': 0, 'days': 0},
    {'label': '2 Years',  'years': 2, 'months': 0, 'days': 0},
    {'label': '3 Years',  'years': 3, 'months': 0, 'days': 0},
    {'label': '5 Years',  'years': 5, 'months': 0, 'days': 0},
  ];

  CustomerType _customerType = CustomerType.regular;
  double _depositAmount = 100000;
  String _selectedBankType = 'All';

  final Map<String, int> _tenureOptions = {
    '1 Year': 365,
    '2 Years': 730,
    '3 Years': 1095,
    '5 Years': 1825,
  };

  final List<String> _bankTypes = ['All', 'Public', 'Private', 'Small Finance', 'Foreign'];

  String? _validateCalendarInput(int y, int m, int d) {
    if (y < 0 || m < 0 || d < 0) {
      return 'Tenure components must be non-negative.';
    }
    if (m > 11) {
      return 'Months must be between 0 and 11.';
    }
    if (y == 0 && m == 0 && d == 0) {
      return 'At least one tenure component must be greater than zero.';
    }
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _tenureDomain != TenureDomain.days ||
      _tenureDays != 365 ||
      _calYears != 1 ||
      _calMonths != 0 ||
      _calDays != 0 ||
      _customerType != CustomerType.regular ||
      _selectedBankType != 'All' ||
      _depositAmount != 100000;

  int get _activeFilterCount {
    int count = 0;
    if (_tenureDomain == TenureDomain.calendar) {
      count++;
    } else if (_tenureDays != 365) {
      count++;
    }
    if (_customerType != CustomerType.regular) count++;
    if (_selectedBankType != 'All') count++;
    if (_depositAmount != 100000) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _tenureDomain = TenureDomain.days;
      _tenureDays = 365;
      _calYears = 1;
      _calMonths = 0;
      _calDays = 0;
      _calendarValidationError = null;
      _customerType = CustomerType.regular;
      _selectedBankType = 'All';
      _depositAmount = 100000;
    });
    if (_selectedSource == 'verified') _loadVerifiedRates();
  }

  String get _currentTenureLabel {
    if (_tenureDomain == TenureDomain.calendar) {
      for (final p in _calendarPresets) {
        if (p['years'] == _calYears && p['months'] == _calMonths && p['days'] == _calDays) {
          return p['label'] as String;
        }
      }
      final parts = <String>[];
      if (_calYears > 0) parts.add('$_calYears ${_calYears == 1 ? 'Year' : 'Years'}');
      if (_calMonths > 0) parts.add('$_calMonths ${_calMonths == 1 ? 'Month' : 'Months'}');
      if (_calDays > 0) parts.add('$_calDays ${_calDays == 1 ? 'Day' : 'Days'}');
      return parts.isEmpty ? '0 Days' : parts.join(' ');
    }
    for (final entry in _tenureOptions.entries) {
      if (entry.value == _tenureDays) return entry.key;
    }
    return '${_tenureDays}d';
  }

  Widget _buildSourceSegmentedControl(BuildContext context, bool isDark, Color gold) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132235) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const ValueKey('compare_source_unverified'),
              onTap: () => setState(() => _selectedSource = 'all'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedSource == 'all'
                      ? (isDark ? const Color(0xFF1E3A5F) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedSource == 'all' && !isDark
                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'All Banks (Reference)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _selectedSource == 'all' ? FontWeight.bold : FontWeight.w500,
                    color: _selectedSource == 'all'
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              key: const ValueKey('compare_source_verified'),
              onTap: () {
                setState(() => _selectedSource = 'verified');
                _loadVerifiedRates();
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedSource == 'verified'
                      ? const Color(0xFF052E16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: _selectedSource == 'verified'
                      ? Border.all(color: const Color(0xFF16A34A), width: 1)
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: _selectedSource == 'verified' ? const Color(0xFF22C55E) : Colors.grey,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Verified Rates',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _selectedSource == 'verified' ? FontWeight.bold : FontWeight.w500,
                          color: _selectedSource == 'verified'
                              ? const Color(0xFF22C55E)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersButton(BuildContext context, bool isDark, Color gold) {
    final hasFilters = _hasActiveFilters;
    return InkWell(
      key: const ValueKey('compare_filters_button'),
      onTap: () => _showFilterBottomSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: hasFilters ? gold.withValues(alpha: 0.15) : (isDark ? const Color(0xFF1A2634) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasFilters ? gold : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, size: 16, color: hasFilters ? gold : (isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(width: 4),
            Text(
              hasFilters ? 'Filters ($_activeFilterCount)' : 'Filters',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasFilters ? gold : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTypeChip(BuildContext context, bool isDark, Color gold) {
    final isSenior = _customerType == CustomerType.seniorCitizen;
    return InkWell(
      key: const ValueKey('compare_customer_chip'),
      onTap: () {
        setState(() {
          _customerType = isSenior ? CustomerType.regular : CustomerType.seniorCitizen;
        });
        if (_selectedSource == 'verified') _loadVerifiedRates();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSenior ? gold.withValues(alpha: 0.15) : (isDark ? const Color(0xFF1A2634) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSenior ? gold : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: 14, color: isSenior ? gold : (isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(width: 4),
            Text(
              isSenior ? 'Customer: Senior' : 'Customer: Regular',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSenior ? FontWeight.bold : FontWeight.normal,
                color: isSenior ? gold : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenureChip(BuildContext context, bool isDark, Color gold) {
    final isCustom = _tenureDomain == TenureDomain.calendar || _tenureDays != 365;
    return InkWell(
      key: const ValueKey('compare_tenure_chip'),
      onTap: () => _showFilterBottomSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isCustom ? gold.withValues(alpha: 0.15) : (isDark ? const Color(0xFF1A2634) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCustom ? gold : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 14, color: isCustom ? gold : (isDark ? Colors.white54 : Colors.black45)),
            const SizedBox(width: 4),
            Text(
              'Tenure: $_currentTenureLabel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
                color: isCustom ? gold : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: isCustom ? gold : (isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositChip(BuildContext context, bool isDark, Color gold) {
    final isCustom = _depositAmount != 100000;
    return InkWell(
      key: const ValueKey('compare_deposit_chip'),
      onTap: () => _showFilterBottomSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isCustom ? gold.withValues(alpha: 0.15) : (isDark ? const Color(0xFF1A2634) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCustom ? gold : (isDark ? Colors.white12 : Colors.black12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.currency_rupee, size: 14, color: isCustom ? gold : (isDark ? Colors.white54 : Colors.black45)),
            Text(
              'Deposit: ${FinancialMath.formatCurrencyRounded(_depositAmount)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
                color: isCustom ? gold : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: isCustom ? gold : (isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color gold = Color(0xFFC9A96E);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            int count;
            if (_selectedSource == 'verified') {
              final matchingVerified = _verifiedRates.where((r) {
                if (_tenureDomain == TenureDomain.calendar) {
                  if (r.tenureDomain != TenureDomain.calendar) return false;
                  return r.coversCalendarTenure(years: _calYears, months: _calMonths, daysCal: _calDays) == true;
                } else {
                  if (r.tenureDomain != TenureDomain.days) return false;
                  return r.coverstenure(_tenureDays);
                }
              }).where((r) {
                if (_selectedBankType == 'All') return true;
                final bank = BankRateRepository.getBankById(r.bankId) ?? r.toBank();
                return bank.typeLabel.toLowerCase().contains(_selectedBankType.toLowerCase());
              });
              count = matchingVerified.length;
            } else {
              final effectiveTenureDays = _tenureDomain == TenureDomain.days
                  ? _tenureDays
                  : (_calYears * 365 + _calMonths * 30 + _calDays);
              final currentComparison = BankRateRepository.compareRates(
                tenureDays: effectiveTenureDays,
                customerType: _customerType,
              );
              final currentTypeFiltered = _selectedBankType == 'All'
                  ? currentComparison
                  : currentComparison.where((entry) {
                      final bank = entry['bank'] as Bank?;
                      if (bank == null) return false;
                      return bank.typeLabel.toLowerCase().contains(_selectedBankType.toLowerCase());
                    }).toList();
              count = currentTypeFiltered.length;
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
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
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter FD Rates',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (_hasActiveFilters)
                            TextButton(
                              onPressed: () {
                                _resetFilters();
                                setSheetState(() {});
                              },
                              child: const Text('Reset to default', style: TextStyle(color: gold)),
                            ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Customer Type
                      Text(
                        'Customer Type',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<CustomerType>(
                        segments: const [
                          ButtonSegment(value: CustomerType.regular, label: Text('Regular', style: TextStyle(fontSize: 12))),
                          ButtonSegment(value: CustomerType.seniorCitizen, label: Text('Senior Citizen', style: TextStyle(fontSize: 12))),
                        ],
                        selected: {_customerType},
                        onSelectionChanged: (v) {
                          setState(() => _customerType = v.first);
                          setSheetState(() {});
                        },
                        style: const ButtonStyle(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bank Type
                      Text(
                        'Bank Type',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _bankTypes.map((type) => ChoiceChip(
                          label: Text(type, style: const TextStyle(fontSize: 12)),
                          selected: _selectedBankType == type,
                          selectedColor: gold.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: _selectedBankType == type ? gold : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: _selectedBankType == type ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedBankType = type);
                            setSheetState(() {});
                          },
                        ),).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Tenure
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tenure',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            _tenureDomain == TenureDomain.calendar ? 'Calendar Domain' : 'Days Domain',
                            style: const TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tenure Domain Switcher: Days vs Calendar
                      SegmentedButton<TenureDomain>(
                        key: const ValueKey('compare_tenure_domain_toggle'),
                        segments: const [
                          ButtonSegment(
                            value: TenureDomain.days,
                            label: Text('Days', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.calendar_today, size: 14),
                          ),
                          ButtonSegment(
                            value: TenureDomain.calendar,
                            label: Text('Calendar', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.date_range, size: 14),
                          ),
                        ],
                        selected: {_tenureDomain},
                        onSelectionChanged: (v) {
                          setState(() {
                            _tenureDomain = v.first;
                            if (_tenureDomain == TenureDomain.calendar) {
                              _calendarValidationError = _validateCalendarInput(_calYears, _calMonths, _calDays);
                            } else {
                              _calendarValidationError = null;
                            }
                          });
                          setSheetState(() {});
                        },
                        style: const ButtonStyle(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_tenureDomain == TenureDomain.days) ...[
                        Row(
                          children: _tenureOptions.entries.map((e) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () {
                                  setState(() => _tenureDays = e.value);
                                  setSheetState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _tenureDays == e.value ? gold : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _tenureDays == e.value ? gold : (isDark ? Colors.white24 : Colors.black26),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    e.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _tenureDays == e.value ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )).toList(),
                        ),
                      ] else ...[
                        // Calendar presets
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _calendarPresets.map((p) {
                            final isPresetSelected = _calYears == p['years'] && _calMonths == p['months'] && _calDays == p['days'];
                            return ChoiceChip(
                              key: ValueKey('calendar_preset_${p['label']}'),
                              label: Text(p['label'] as String, style: const TextStyle(fontSize: 12)),
                              selected: isPresetSelected,
                              selectedColor: gold.withValues(alpha: 0.25),
                              labelStyle: TextStyle(
                                color: isPresetSelected ? gold : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: isPresetSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _calYears = p['years'] as int;
                                  _calMonths = p['months'] as int;
                                  _calDays = p['days'] as int;
                                  _calendarValidationError = null;
                                });
                                setSheetState(() {});
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        // Custom Calendar Component Inputs
                        Row(
                          children: [
                            Expanded(
                              child: _buildComponentInput(
                                label: 'Years',
                                value: _calYears,
                                onChanged: (val) {
                                  final y = int.tryParse(val) ?? 0;
                                  setState(() {
                                    _calYears = y;
                                    _calendarValidationError = _validateCalendarInput(_calYears, _calMonths, _calDays);
                                  });
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                                gold: gold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildComponentInput(
                                label: 'Months',
                                value: _calMonths,
                                onChanged: (val) {
                                  final m = int.tryParse(val) ?? 0;
                                  setState(() {
                                    _calMonths = m;
                                    _calendarValidationError = _validateCalendarInput(_calYears, _calMonths, _calDays);
                                  });
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                                gold: gold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildComponentInput(
                                label: 'Days',
                                value: _calDays,
                                onChanged: (val) {
                                  final d = int.tryParse(val) ?? 0;
                                  setState(() {
                                    _calDays = d;
                                    _calendarValidationError = _validateCalendarInput(_calYears, _calMonths, _calDays);
                                  });
                                  setSheetState(() {});
                                },
                                isDark: isDark,
                                gold: gold,
                              ),
                            ),
                          ],
                        ),
                        if (_calendarValidationError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _calendarValidationError!,
                            key: const ValueKey('calendar_validation_error_text'),
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),

                      // Deposit Amount
                      Row(
                        children: [
                          Text(
                            'Deposit Amount: ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            FinancialMath.formatCurrencyRounded(_depositAmount),
                            style: const TextStyle(fontSize: 14, color: gold, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: gold,
                          thumbColor: gold,
                          inactiveTrackColor: gold.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: _depositAmount,
                          min: 10000,
                          max: 10000000,
                          divisions: 100,
                          onChanged: (v) {
                            setState(() => _depositAmount = v);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gold,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: (_tenureDomain == TenureDomain.calendar && _calendarValidationError != null)
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                  if (_selectedSource == 'verified') _loadVerifiedRates();
                                },
                          child: Text(
                            'Apply Filters ($count rates)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildComponentInput({
    required String label,
    required int value,
    required ValueChanged<String> onChanged,
    required bool isDark,
    required Color gold,
  }) {
    return TextFormField(
      key: ValueKey('calendar_input_$label'),
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: gold, width: 1.5),
        ),
      ),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color gold = Color(0xFFC9A96E);

    final effectiveTenureDays = _tenureDomain == TenureDomain.days
        ? _tenureDays
        : (_calYears * 365 + _calMonths * 30 + _calDays);

    // Get filtered rates
    final comparison = BankRateRepository.compareRates(
      tenureDays: effectiveTenureDays,
      customerType: _customerType,
    );

    // Further filter by bank type
    final typeFiltered = _selectedBankType == 'All'
        ? comparison
        : comparison.where((entry) {
            final bank = entry['bank'] as Bank?;
            if (bank == null) return false;
            return bank.typeLabel.toLowerCase().contains(_selectedBankType.toLowerCase());
          }).toList();

    // Further filter by search query (case-insensitive, trimmed, partial match)
    final trimmedQuery = _searchQuery.trim().toLowerCase();
    final filtered = trimmedQuery.isEmpty
        ? typeFiltered
        : typeFiltered.where((entry) {
            final bank = entry['bank'] as Bank?;
            if (bank == null) return false;
            final name = bank.name.toLowerCase();
            final shortName = bank.shortName.toLowerCase();
            final id = bank.id.toLowerCase();
            final combined = '$name $shortName ${bank.typeLabel.toLowerCase()}';
            return name.contains(trimmedQuery) ||
                shortName.contains(trimmedQuery) ||
                id.contains(trimmedQuery) ||
                combined.contains(trimmedQuery);
          }).toList();

    // Filter verified rates by search query and domain matching
    bool hasIndeterminateMatches = false;
    final verifiedFiltered = _verifiedRates.where((r) {
      if (_tenureDomain == TenureDomain.calendar) {
        if (r.tenureDomain != TenureDomain.calendar) return false;
        final matched = r.coversCalendarTenure(years: _calYears, months: _calMonths, daysCal: _calDays);
        if (matched == null) {
          hasIndeterminateMatches = true;
          return false; // Unresolved coverage is never presented as confirmed match
        }
        return matched == true;
      } else {
        if (r.tenureDomain != TenureDomain.days) return false;
        return r.coverstenure(_tenureDays);
      }
    }).where((r) {
      if (trimmedQuery.isEmpty) return true;
      final name = r.bankName.toLowerCase();
      final shortName = r.bankShortName.toLowerCase();
      final id = r.bankId.toLowerCase();
      final text = r.sourceTenureText?.toLowerCase() ?? '';
      return name.contains(trimmedQuery) ||
          shortName.contains(trimmedQuery) ||
          id.contains(trimmedQuery) ||
          text.contains(trimmedQuery);
    }).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[50],
        appBar: const CustomAppBar(title: 'Compare FD Rates', showBackButton: false),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: CustomScrollView(
                slivers: [
                  // Compact Filters
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      decoration: BoxDecoration(
                        color: isDark ? Theme.of(context).cardColor : Colors.white,
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Source Switcher: Unverified Reference vs Official Verified
                          _buildSourceSegmentedControl(context, isDark, gold),

                          // Two-Bank Comparison Banner
                          InkWell(
                            key: const ValueKey('open_two_bank_compare_button'),
                            onTap: () => context.push('/compare/two-banks'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [gold.withAlpha(45), gold.withAlpha(15)]
                                      : [gold.withAlpha(35), gold.withAlpha(15)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: gold.withAlpha(80)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: gold.withAlpha(40),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.compare_arrows_rounded, color: gold, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Compare Two Banks Side-by-Side',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          'Direct like-for-like FD rates & terms comparison',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: gold),
                                ],
                              ),
                            ),
                          ),

                          if (!RateDisplayConfig.isLiveRateDisplayEnabled) ...[
                            const OfficialRatesNoticeCard(compact: true),
                            const SizedBox(height: 12),
                          ],

                          // Bank Search Field
                          TextField(
                            controller: _searchController,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search banks...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: isDark ? Colors.white54 : Colors.black45,
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              isDense: true,
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1A2634) : Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: gold, width: 1.5),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() => _searchQuery = val);
                            },
                          ),
                          const SizedBox(height: 10),

                          // Compact Horizontally Scrollable Filter Bar
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFiltersButton(context, isDark, gold),
                                const SizedBox(width: 8),
                                _buildCustomerTypeChip(context, isDark, gold),
                                const SizedBox(width: 8),
                                ..._bankTypes.map((type) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(type, style: const TextStyle(fontSize: 12)),
                                    selected: _selectedBankType == type,
                                    selectedColor: gold.withValues(alpha: 0.2),
                                    labelStyle: TextStyle(
                                      color: _selectedBankType == type ? gold : (isDark ? Colors.white70 : Colors.black87),
                                      fontWeight: _selectedBankType == type ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    onSelected: (_) => setState(() => _selectedBankType = type),
                                  ),
                                ),),
                                _buildTenureChip(context, isDark, gold),
                                const SizedBox(width: 8),
                                _buildDepositChip(context, isDark, gold),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Summary
                          Row(
                            children: [
                              Text(
                                _selectedSource == 'verified'
                                    ? '${verifiedFiltered.length} verified rates found'
                                    : (_tenureDomain == TenureDomain.calendar
                                        ? '${filtered.length} reference rates (approx. days)'
                                        : '${filtered.length} rates found'),
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                              ),
                              if (_hasActiveFilters) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _resetFilters,
                                  child: const Text(
                                    'Reset all',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: gold,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (_selectedSource == 'verified')
                                const VerifiedRateBadge()
                              else
                                const VerificationBadge(status: VerificationStatus.pendingReview, compact: false),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Results
                if (_selectedSource == 'verified') ...[
                  if (_isLoadingVerified)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF10B981)),
                      ),
                    )
                  else if (verifiedFiltered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.trim().isNotEmpty
                                    ? 'No verified rates matching "${_searchQuery.trim()}"'
                                    : (hasIndeterminateMatches
                                        ? 'Exact calendar tenure coverage is unresolved without an anchor deposit date.\nNo confirmed verified rates available for this interval.'
                                        : 'No verified rates found for this criteria.\nSwitch to "All Banks (Reference)" for unverified bank estimates.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                              ),
                              if (_searchQuery.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.clear, size: 16, color: gold),
                                  label: const Text('Clear search', style: TextStyle(color: gold)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: Responsive.screenPadding(context),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final vRate = verifiedFiltered[index];
                            final bank = BankRateRepository.getBankById(vRate.bankId) ?? vRate.toBank();
                            final rate = vRate.toFdRate();

                            return FdRateCard(
                              bank: bank,
                              rate: rate,
                              tenureLabel: vRate.tenureDescription,
                              onTap: () => context.push('/bank/${Uri.encodeComponent(bank.name)}'),
                            );
                          },
                          childCount: verifiedFiltered.length,
                        ),
                      ),
                    ),
                ] else ...[
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.trim().isNotEmpty
                                    ? 'No banks found matching "${_searchQuery.trim()}"'
                                    : 'No rates found for this criteria',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                              ),
                              if (_searchQuery.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.clear, size: 16, color: gold),
                                  label: const Text('Clear search', style: TextStyle(color: gold)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: Responsive.screenPadding(context),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry = filtered[index];
                            final bank = entry['bank'] as Bank?;
                            final rate = entry['rate'] as FdRate;
                            if (bank == null) return const SizedBox.shrink();

                            return FdRateCard(
                              bank: bank,
                              rate: rate,
                              tenureLabel: _tenureDomain == TenureDomain.calendar
                                  ? 'Approx. ${FdRateCard.formatTenure(rate.minTenureDays, rate.maxTenureDays)}'
                                  : null,
                              onTap: () => context.push('/bank/${Uri.encodeComponent(bank.name)}'),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
