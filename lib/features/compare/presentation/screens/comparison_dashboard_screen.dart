import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/data/bank_data.dart';
import '../../../../core/services/rate_display_config.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/official_rates_notice_card.dart';

class ComparisonDashboardScreen extends StatelessWidget {
  const ComparisonDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Banks Dashboard'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                TabBar(
                  isScrollable: Responsive.isMobile(context),
                  tabAlignment: Responsive.isMobile(context) ? TabAlignment.start : TabAlignment.fill,
                  tabs: const [
                    Tab(text: '1 Year'),
                    Tab(text: '2 Year'),
                    Tab(text: '3 Year'),
                    Tab(text: '5 Year'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildList(context, '1y'),
                      _buildList(context, '2y'),
                      _buildList(context, '3y'),
                      _buildList(context, '5y'),
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

  Widget _buildList(BuildContext context, String duration) {
    if (!RateDisplayConfig.isLiveRateDisplayEnabled) {
      return Padding(
        padding: Responsive.screenPadding(context),
        child: const Center(
          child: OfficialRatesNoticeCard(
            title: 'Bank Rates Dashboard',
            message: 'Official bank rates are being verified and will be available in a future update.',
            subtext: 'The multi-tenure comparison dashboard will be activated once official rate slabs are verified and published.',
          ),
        ),
      );
    }

    final topBanks = BankDataService.getTopBanksByRate(duration, limit: 20);
    return GridView.builder(
      padding: Responsive.screenPadding(context),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.gridCrossAxisCount(context, mobile: 1, tablet: 2, desktop: 3),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 70, // Fixed height for ListTile
      ),
      itemCount: topBanks.length,
      itemBuilder: (context, index) {
        final bank = topBanks[index];
        final rate = bank.fdRates[duration] ?? 0.0;
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => context.push('/bank/${Uri.encodeComponent(bank.name)}'),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text('${index + 1}', style: TextStyle(color: Theme.of(context).primaryColor)),
            ),
            title: Text(bank.name, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(bank.type.toUpperCase(), style: const TextStyle(fontSize: 12)),
            trailing: Text('${rate.toStringAsFixed(2)}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).primaryColor)),
          ),
        );
      },
    );
  }
}
