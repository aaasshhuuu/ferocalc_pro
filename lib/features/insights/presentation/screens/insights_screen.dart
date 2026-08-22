import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/services/bank_rate_api_service.dart';
import '../../../../core/utils/responsive.dart';


class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

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

            // Interest Rate Tracker
            Text('Interest Rate Tracker', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 12),
            GlassmorphicCard(
              child: Column(
                children: [
                  _buildInterestRow('RBI Repo Rate', '6.50%', isDark, gold),
                  const Divider(),
                  _buildInterestRow('SBI Base Rate', '10.40%', isDark, gold),
                  const Divider(),
                  _buildInterestRow('PPF Rate', '7.10%', isDark, gold),
                  const Divider(),
                  _buildInterestRow('Sukanya Samriddhi', '8.20%', isDark, gold),
                  const SizedBox(height: 12),
                  const Text(
                    'Indicative rates for reference only. Verify current rates with official sources before making financial decisions.',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Financial News/Tips Cards
            Text('Financial Literacy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor))
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
                children: [
                  _buildLiteracyCard('Rule of 72', 'Divide 72 by interest rate to know doubling time', Icons.calculate, gold, isDark),
                  _buildLiteracyCard('Emergency Fund', 'Emergency fund should cover 6 months of expenses', Icons.security, gold, isDark),
                  _buildLiteracyCard('Start SIP Early', '₹5000/mo for 30 years at 12% = ₹1.76 Cr', Icons.trending_up, gold, isDark),
                  _buildLiteracyCard('Tax Saving', 'Section 80C allows ₹1.5L deduction', Icons.account_balance, gold, isDark),
                  _buildLiteracyCard('PPF Returns', 'PPF gives 7.1% tax-free returns', Icons.account_balance_wallet, gold, isDark),
                  _buildLiteracyCard('NPS Benefits', 'NPS gives extra ₹50,000 deduction under 80CCD(1B)', Icons.savings, gold, isDark),
                  _buildLiteracyCard('FD Taxation', 'FD interest is taxable; consider tax-saver FDs', Icons.request_quote, gold, isDark),
                  _buildLiteracyCard('Sukanya Samriddhi', '8.2% for girl child savings', Icons.child_care, gold, isDark),
                ].animate(interval: 100.ms).fade(),
              )
            else
              SizedBox(
                height: 160,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildLiteracyCard('Rule of 72', 'Divide 72 by interest rate to know doubling time', Icons.calculate, gold, isDark),
                    _buildLiteracyCard('Emergency Fund', 'Emergency fund should cover 6 months of expenses', Icons.security, gold, isDark),
                    _buildLiteracyCard('Start SIP Early', '₹5000/mo for 30 years at 12% = ₹1.76 Cr', Icons.trending_up, gold, isDark),
                    _buildLiteracyCard('Tax Saving', 'Section 80C allows ₹1.5L deduction', Icons.account_balance, gold, isDark),
                    _buildLiteracyCard('PPF Returns', 'PPF gives 7.1% tax-free returns', Icons.account_balance_wallet, gold, isDark),
                    _buildLiteracyCard('NPS Benefits', 'NPS gives extra ₹50,000 deduction under 80CCD(1B)', Icons.savings, gold, isDark),
                    _buildLiteracyCard('FD Taxation', 'FD interest is taxable; consider tax-saver FDs', Icons.request_quote, gold, isDark),
                    _buildLiteracyCard('Sukanya Samriddhi', '8.2% for girl child savings', Icons.child_care, gold, isDark),
                  ].animate(interval: 100.ms).fade(),
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


  Widget _buildInterestRow(String name, String rate, bool isDark, Color gold) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: TextStyle(fontWeight: FontWeight.w500, color: textColor)),
          Text(rate, style: TextStyle(fontWeight: FontWeight.bold, color: gold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildLiteracyCard(String title, String content, IconData icon, Color gold, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2634) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: gold, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              content,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCalcBtn(String title, IconData icon, Color gold, bool isDark) {
    return InkWell(
      onTap: () {},
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
