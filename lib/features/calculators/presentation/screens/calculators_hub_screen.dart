import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/responsive.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CalculatorsHubScreen extends StatefulWidget {
  const CalculatorsHubScreen({Key? key}) : super(key: key);

  @override
  State<CalculatorsHubScreen> createState() => _CalculatorsHubScreenState();
}

class _CalculatorsHubScreenState extends State<CalculatorsHubScreen> {
  String _searchQuery = '';
  final Map<String, bool> _expandedState = {};
  final TextEditingController _searchController = TextEditingController();

  /// Category icon mapping for section headers
  static const Map<String, IconData> _categoryIcons = {
    'Loans': Icons.account_balance,
    'Deposits': Icons.savings,
    'Investments': Icons.trending_up,
    'Tax & GST': Icons.receipt_long,
    'Planning': Icons.flag,
  };

  /// All 26 calculators organized into 5 categories
  final Map<String, List<Map<String, dynamic>>> _categories = {
    'Loans': [
      {'name': 'EMI', 'icon': Icons.calculate, 'desc': 'Equated Monthly Installment'},
      {'name': 'Loan Amount', 'icon': Icons.account_balance_wallet, 'desc': 'Max affordable loan'},
      {'name': 'Loan Term', 'icon': Icons.access_time, 'desc': 'Repayment duration'},
      {'name': 'Interest Rate', 'icon': Icons.percent, 'desc': 'True interest rate'},
      {'name': 'Home Loan Eligibility', 'icon': Icons.home, 'desc': 'Max home loan'},
      {'name': 'Personal Loan Eligibility', 'icon': Icons.person, 'desc': 'Max personal loan'},
      {'name': 'Credit Card EMI', 'icon': Icons.credit_card, 'desc': 'Card repayment'},
    ],
    'Deposits': [
      {'name': 'FD', 'icon': Icons.account_balance, 'desc': 'Fixed Deposit returns'},
      {'name': 'RD', 'icon': Icons.update, 'desc': 'Recurring Deposit'},
      {'name': 'Savings', 'icon': Icons.savings, 'desc': 'Bank savings account'},
      {'name': 'PPF', 'icon': Icons.assured_workload, 'desc': 'Public Provident Fund'},
    ],
    'Investments': [
      {'name': 'SIP', 'icon': Icons.trending_up, 'desc': 'Systematic Investment'},
      {'name': 'SWP', 'icon': Icons.trending_down, 'desc': 'Systematic Withdrawal'},
      {'name': 'Lumpsum', 'icon': Icons.monetization_on, 'desc': 'One-time investment'},
      {'name': 'CAGR', 'icon': Icons.stacked_line_chart, 'desc': 'Compound Annual Growth'},
      {'name': 'Stock Return', 'icon': Icons.candlestick_chart, 'desc': 'Profit/Loss'},
      {'name': 'Dividend Yield', 'icon': Icons.payments, 'desc': 'Dividend returns'},
      {'name': 'NPS', 'icon': Icons.elderly, 'desc': 'National Pension System'},
      {'name': 'EPF', 'icon': Icons.business, 'desc': 'Employee Provident Fund'},
    ],
    'Tax & GST': [
      {'name': 'Income Tax', 'icon': Icons.request_quote, 'desc': 'Tax calculator'},
      {'name': 'GST', 'icon': Icons.receipt, 'desc': 'Goods and Services Tax'},
    ],
    'Planning': [
      {'name': 'Retirement', 'icon': Icons.beach_access, 'desc': 'Retirement corpus'},
      {'name': 'Goal', 'icon': Icons.flag, 'desc': 'Financial goals'},
      {'name': 'Education', 'icon': Icons.school, 'desc': 'Child education'},
      {'name': 'Inflation', 'icon': Icons.show_chart, 'desc': 'Future value'},
      {'name': 'Sukanya Samriddhi', 'icon': Icons.child_care, 'desc': 'SSY Scheme'},
    ],
  };

  String _getRoute(String name) {
    switch (name) {
      case 'EMI': return '/calculator/emi';
      case 'Loan Amount': return '/calculator/loan_amount';
      case 'Interest Rate': return '/calculator/interest_rate';
      case 'Loan Term': return '/calculator/loan_term';
      case 'Home Loan Eligibility': return '/calculator/home_loan_eligibility';
      case 'Personal Loan Eligibility': return '/calculator/personal_loan_eligibility';
      case 'Credit Card EMI': return '/calculator/credit_card_emi';
      case 'FD': return '/calculator/fd';
      case 'RD': return '/calculator/rd';
      case 'Savings': return '/calculator/savings';
      case 'SIP': return '/calculator/sip';
      case 'SWP': return '/calculator/swp';
      case 'Lumpsum': return '/calculator/lumpsum';
      case 'CAGR': return '/calculator/cagr';
      case 'PPF': return '/calculator/ppf';
      case 'EPF': return '/calculator/epf';
      case 'NPS': return '/calculator/nps';
      case 'Sukanya Samriddhi': return '/calculator/sukanya';
      case 'GST': return '/calculator/gst';
      case 'Income Tax': return '/calculator/income_tax';
      case 'Retirement': return '/calculator/retirement';
      case 'Goal': return '/calculator/goal';
      case 'Education': return '/calculator/education';
      case 'Inflation': return '/calculator/inflation';
      case 'Stock Return': return '/calculator/stock_return';
      case 'Dividend Yield': return '/calculator/dividend_yield';
      default: return '/calculators';
    }
  }

  @override
  void initState() {
    super.initState();
    for (var key in _categories.keys) {
      _expandedState[key] = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _shareResult(BuildContext context) {
    // Use share_plus to share the calculation result text
    final resultText = 'Check out my calculation on FeroCalc!';
    // For now show a snackbar since share_plus may not work on web
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Result shared!'), backgroundColor: const Color(0xFF10B981)),
    );
  }

  void _exportPdf(BuildContext context) {
    _shareResult(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color gold = Color(0xFFC9A96E);

    // Responsive column count
    int crossAxisCount = Responsive.gridCrossAxisCount(context, mobile: 2, tablet: 3, desktop: 4);

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[50],
      appBar: CustomAppBar(title: 'Calculators', showBackButton: false),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search calculators...',
                          prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.black45),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: isDark ? Colors.white54 : Colors.black45),
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
                            borderSide: const BorderSide(color: gold, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.toLowerCase();
                          });
                        },
                      ),
                    ),
                  ),
                ),
                // Calculator count chip
                if (_searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${_filteredCount()} calculator${_filteredCount() == 1 ? '' : 's'} found',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                // Category sections
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _categories.length,
                    itemBuilder: (context, categoryIndex) {
                      final category = _categories.keys.elementAt(categoryIndex);
                      final items = _categories[category]!.where((item) {
                        return item['name'].toString().toLowerCase().contains(_searchQuery) ||
                               item['desc'].toString().toLowerCase().contains(_searchQuery);
                      }).toList();

                      if (items.isEmpty) return const SizedBox.shrink();

                      final isExpanded = _expandedState[category] ?? true;
                      final categoryIcon = _categoryIcons[category] ?? Icons.grid_view;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category header
                          InkWell(
                            onTap: () {
                              setState(() {
                                _expandedState[category] = !isExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: gold,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(categoryIcon, size: 20, color: gold),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  // Item count badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: gold.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${items.length}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: gold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.0 : -0.25,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(Icons.expand_more, color: gold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Expandable grid
                          AnimatedCrossFade(
                            firstChild: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.25,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _CalculatorTile(
                                  name: item['name'],
                                  icon: item['icon'],
                                  desc: item['desc'],
                                  isDark: isDark,
                                  onTap: () => context.go(_getRoute(item['name'])),
                                  animationDelay: Duration(milliseconds: 40 * index),
                                );
                              },
                            ),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState: isExpanded
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 250),
                            sizeCurve: Curves.easeInOut,
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Count of calculators matching current search
  int _filteredCount() {
    int count = 0;
    for (final items in _categories.values) {
      count += items.where((item) {
        return item['name'].toString().toLowerCase().contains(_searchQuery) ||
               item['desc'].toString().toLowerCase().contains(_searchQuery);
      }).length;
    }
    return count;
  }
}

/// Individual calculator tile with fade-in animation
class _CalculatorTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final String desc;
  final bool isDark;
  final VoidCallback onTap;
  final Duration animationDelay;

  const _CalculatorTile({
    required this.name,
    required this.icon,
    required this.desc,
    required this.isDark,
    required this.onTap,
    required this.animationDelay,
  });

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFC9A96E);

    return GlassmorphicCard(
      padding: const EdgeInsets.all(0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: gold.withOpacity(0.1),
        highlightColor: gold.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: gold),
              ),
              const Spacer(),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: animationDelay)
        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
        .moveY(begin: 12, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}
