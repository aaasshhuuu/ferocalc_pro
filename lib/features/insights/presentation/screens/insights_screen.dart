import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/financial_management_data.dart';
import '../../../../core/models/financial_management_topic.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';


class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  static String? getRouteForTitle(String title) {
    switch (title.trim()) {
      // Quick Calculators
      case 'SIP Calculator':
        return '/calculator/sip';
      case 'EMI Calculator':
        return '/calculator/emi';
      case 'FD Calculator':
        return '/calculator/fd';
      case 'Tax Calculator':
        return '/calculator/income_tax';
      // Financial Management Topics
      case 'Rule of 72':
        return '/insights/financial-management/rule-of-72';
      case 'Emergency Fund':
        return '/insights/financial-management/emergency-fund';
      case 'Start SIP Early':
        return '/insights/financial-management/start-sip-early';
      case 'Tax Saving':
        return '/insights/financial-management/tax-saving';
      case 'PPF Returns':
        return '/insights/financial-management/ppf-returns';
      case 'NPS Benefits':
        return '/insights/financial-management/nps-benefits';
      case 'FD Taxation':
        return '/insights/financial-management/fd-taxation';
      case 'Sukanya Samriddhi':
        return '/insights/financial-management/sukanya-samriddhi';
      case 'Rule of 114':
        return '/insights/financial-management/rule-of-114';
      case '70/20/10 Rule':
      case '70/20/10':
        return '/insights/financial-management/70-20-10';
      // Financial Literacy Hub
      case 'Financial Literacy':
        return '/financial-literacy';
      default:
        return null;
    }
  }

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final List<String> _tips = [
    "Compound interest is the eighth wonder of the world.",
    "Pay yourself first: Save at least 20% of your income.",
    "Diversification is a protection against ignorance.",
    "Emergency funds should cover 3-6 months of living expenses.",
    "Time in the market beats timing the market.",
    "Don't save what is left after spending, spend what is left after saving.",
    "An investment in knowledge pays the best interest.",
    "Track your net worth, not just your income.",
    "Avoid lifestyle creep as your income grows.",
    "Understand the difference between good debt and bad debt.",
  ];

  late String _currentTip;
  late Timer _timer;
  
  @override
  void initState() {
    super.initState();
    _currentTip = _tips[0];
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _currentTip = _tips[timer.tick % _tips.length];
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final midnight = Theme.of(context).scaffoldBackgroundColor;
    final backgroundColor = isDark ? midnight : theme.colorScheme.surface;
    final gold = const Color(0xFFC9A96E);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: const CustomAppBar(title: 'Insights', showBackButton: false),
      body: SafeArea(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: Responsive.screenPadding(context),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Finance Tip Card
            _buildDailyTipCard(gold).animate().fade(),
            const SizedBox(height: 24),

            // Market Data Section
            Text('Market Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            GlassmorphicCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.signal_wifi_off, size: 48, color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(height: 16),
                    Text(
                      'Market Data Unavailable',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Live market data requires a verified data provider. This feature will be available when a market-data source is configured.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Financial Literacy Hub Entry Section
            Text('Financial Literacy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor))
                .animate().fade(),
            const SizedBox(height: 12),
            _buildFinancialLiteracyEntryCard(gold, isDark, textColor),
            const SizedBox(height: 24),

            // Financial Management Section
            Text('Financial Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor))
                .animate().fade(),
            const SizedBox(height: 12),
            if (Responsive.isDesktop(context))
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2,
                children: FinancialManagementData.getAllTopics()
                    .map((topic) => _buildManagementCard(topic, gold, isDark))
                    .toList()
                    .animate(interval: 100.ms)
                    .fade(),
              )
            else
              SizedBox(
                height: 160,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: FinancialManagementData.getAllTopics()
                      .map((topic) => _buildManagementCard(topic, gold, isDark))
                      .toList()
                      .animate(interval: 100.ms)
                      .fade(),
                ),
              ),
            const SizedBox(height: 24),

            // Quick Calculator Links
            Text('Quick Calculators', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor))
                .animate().fade(),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: Responsive.gridCrossAxisCount(context, mobile: 2, tablet: 4, desktop: 4),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildQuickCalcBtn('SIP Calculator', Icons.trending_up, gold, isDark),
                _buildQuickCalcBtn('EMI Calculator', Icons.home, gold, isDark),
                _buildQuickCalcBtn('FD Calculator', Icons.account_balance, gold, isDark),
                _buildQuickCalcBtn('Tax Calculator', Icons.receipt, gold, isDark),
              ].animate(interval: 100.ms).fade(),
            ),
            const SizedBox(height: 24),
          ],
        ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildDailyTipCard(Color gold) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Container(
        key: ValueKey<String>(_currentTip),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [gold, gold.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gold.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Tip of the Day', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _currentTip,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildFinancialLiteracyEntryCard(Color gold, bool isDark, Color textColor) {
    return Container(
      key: const ValueKey('financial_literacy_entry_card'),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('financial_literacy_entry_inkwell'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/financial-literacy'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.school_rounded, color: gold, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Financial Literacy Hub',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Learn money, debt, investing & tax concepts',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: gold, size: 16),
                  ],
                ),
                const SizedBox(height: 14),
                _buildLiteracyHighlightRow(Icons.lightbulb_outline_rounded, 'Learn core financial concepts & wealth fundamentals', isDark, gold),
                const SizedBox(height: 6),
                _buildLiteracyHighlightRow(Icons.category_outlined, 'Browse 20+ topics across Banking, Investing, Loans & Taxes', isDark, gold),
                const SizedBox(height: 6),
                _buildLiteracyHighlightRow(Icons.menu_book_rounded, 'Read detailed explanations, rules, and worked examples', isDark, gold),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: gold.withValues(alpha: 0.25)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Explore Financial Literacy Hub',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: gold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: gold, size: 16),
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

  Widget _buildLiteracyHighlightRow(IconData icon, String text, bool isDark, Color gold) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManagementCard(FinancialManagementTopic topic, Color gold, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      key: ValueKey('financial_management_card_${topic.id}'),
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: topic.isKeyTopic ? gold : gold.withOpacity(0.3),
          width: topic.isKeyTopic ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('financial_management_card_inkwell_${topic.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/insights/financial-management/${topic.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(topic.icon, color: gold, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        topic.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (topic.isKeyTopic) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.star, size: 14, color: gold),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    topic.shortDescription,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 13,
                    ),
                    maxLines: 4,
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

  Widget _buildQuickCalcBtn(String title, IconData icon, Color gold, bool isDark) {
    final route = InsightsScreen.getRouteForTitle(title);
    return InkWell(
      onTap: route != null ? () => context.push(route) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2634) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: gold, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
