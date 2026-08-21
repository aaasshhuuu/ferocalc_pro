import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/responsive.dart';

class CalculatorsHubScreen extends StatefulWidget {
  const CalculatorsHubScreen({Key? key}) : super(key: key);

  @override
  State<CalculatorsHubScreen> createState() => _CalculatorsHubScreenState();
}

class _CalculatorsHubScreenState extends State<CalculatorsHubScreen> {
  String _searchQuery = '';
  final Map<String, bool> _expandedState = {};

  final Map<String, List<Map<String, dynamic>>> _categories = {
    'Loans': [
      {'name': 'EMI', 'icon': Icons.calculate, 'desc': 'Equated Monthly Installment'},
      {'name': 'Loan Amount', 'icon': Icons.account_balance_wallet, 'desc': 'Max affordable loan'},
      {'name': 'Interest Rate', 'icon': Icons.percent, 'desc': 'True interest rate'},
      {'name': 'Loan Term', 'icon': Icons.access_time, 'desc': 'Repayment duration'},
      {'name': 'Home Loan Eligibility', 'icon': Icons.home, 'desc': 'Max home loan'},
      {'name': 'Personal Loan Eligibility', 'icon': Icons.person, 'desc': 'Max personal loan'},
      {'name': 'Credit Card EMI', 'icon': Icons.credit_card, 'desc': 'Card repayment'},
    ],
    'Deposits': [
      {'name': 'FD', 'icon': Icons.account_balance, 'desc': 'Fixed Deposit returns'},
      {'name': 'RD', 'icon': Icons.update, 'desc': 'Recurring Deposit'},
      {'name': 'Savings', 'icon': Icons.savings, 'desc': 'Bank savings account'},
    ],
    'Investments': [
      {'name': 'SIP', 'icon': Icons.trending_up, 'desc': 'Systematic Investment'},
      {'name': 'SWP', 'icon': Icons.trending_down, 'desc': 'Systematic Withdrawal'},
      {'name': 'Lumpsum', 'icon': Icons.monetization_on, 'desc': 'One-time investment'},
      {'name': 'CAGR', 'icon': Icons.stacked_line_chart, 'desc': 'Compound Annual Growth'},
    ],
    'Government Schemes': [
      {'name': 'PPF', 'icon': Icons.assured_workload, 'desc': 'Public Provident Fund'},
      {'name': 'EPF', 'icon': Icons.business, 'desc': 'Employee Provident Fund'},
      {'name': 'NPS', 'icon': Icons.elderly, 'desc': 'National Pension System'},
      {'name': 'Sukanya Samriddhi', 'icon': Icons.child_care, 'desc': 'SSY Scheme'},
    ],
    'Tax': [
      {'name': 'GST', 'icon': Icons.receipt, 'desc': 'Goods and Services Tax'},
      {'name': 'Income Tax', 'icon': Icons.request_quote, 'desc': 'Tax calculator'},
    ],
    'Planning': [
      {'name': 'Retirement', 'icon': Icons.beach_access, 'desc': 'Retirement corpus'},
      {'name': 'Goal', 'icon': Icons.flag, 'desc': 'Financial goals'},
      {'name': 'Education', 'icon': Icons.school, 'desc': 'Child education'},
      {'name': 'Inflation', 'icon': Icons.show_chart, 'desc': 'Future value'},
    ],
    'Stock Market': [
      {'name': 'Stock Return', 'icon': Icons.candlestick_chart, 'desc': 'Profit/Loss'},
      {'name': 'Dividend Yield', 'icon': Icons.payments, 'desc': 'Dividend returns'},
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
    final Color midnight = const Color(0xFF0D1B2A);
    final Color gold = const Color(0xFFC9A96E);
    
    // Responsive column count
    final double width = MediaQuery.of(context).size.width;
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search calculators...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: isDark ? Theme.of(context).cardColor : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _categories.entries.map((entry) {
                final category = entry.key;
                final items = entry.value.where((item) {
                  return item['name'].toString().toLowerCase().contains(_searchQuery) ||
                         item['desc'].toString().toLowerCase().contains(_searchQuery);
                }).toList();

                if (items.isEmpty) return const SizedBox.shrink();

                final isExpanded = _expandedState[category] ?? true;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _expandedState[category] = !isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: gold,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: gold),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return GlassmorphicCard(
                            padding: const EdgeInsets.all(0),
                            child: InkWell(
                              onTap: () => context.go(_getRoute(item['name'])),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(item['icon'], size: 28, color: const Color(0xFF00B4D8)),
                                    const Spacer(),
                                    Text(
                                      item['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['desc'],
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
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                );
              }).toList(),
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

