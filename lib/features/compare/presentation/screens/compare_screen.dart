import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/data/bank_data.dart';
import '../../../../core/utils/responsive.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({Key? key}) : super(key: key);

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  String _selectedDurationKey = '1y';
  String _selectedType = 'All';

  final Map<String, String> _durations = {'1y': '1yr', '2y': '2yr', '3y': '3yr', '5y': '5yr'};
  final List<String> _types = ['All', 'Public', 'Private', 'Small Finance', 'Foreign', 'Global'];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color midnight = const Color(0xFF0D1B2A);
    final Color gold = const Color(0xFFC9A96E);
    final Color emerald = const Color(0xFF10B981);
    final Color teal = const Color(0xFF00B4D8);

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[50],
      appBar: const CustomAppBar(title: 'Compare Rates', showBackButton: false),
      body: SafeArea(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
          // Filters section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Theme.of(context).cardColor : Colors.white,
              boxShadow: [
                if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bank Type', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _types.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: _selectedType == type,
                        selectedColor: teal.withOpacity(0.2),
                        labelStyle: TextStyle(color: _selectedType == type ? teal : (isDark ? Colors.white70 : Colors.black87)),
                        onSelected: (val) => setState(() => _selectedType = type),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _durations.entries.map((e) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: InkWell(
                        onTap: () => setState(() => _selectedDurationKey = e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedDurationKey == e.key ? Theme.of(context).primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _selectedDurationKey == e.key ? Theme.of(context).primaryColor : (isDark ? Colors.white24 : Colors.black26)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            e.value, 
                            style: TextStyle(
                              color: _selectedDurationKey == e.key ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          
          // Results
          Expanded(
            child: Builder(
              builder: (context) {
                var banks = BankDataService.getBanksByType(_selectedType);
                banks.sort((a, b) {
                  final rateA = a.fdRates[_selectedDurationKey] ?? 0.0;
                  final rateB = b.fdRates[_selectedDurationKey] ?? 0.0;
                  return rateB.compareTo(rateA);
                });

                return GridView.builder(
                  padding: Responsive.screenPadding(context),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.gridCrossAxisCount(context, mobile: 1, tablet: 2, desktop: 2),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 100,
                  ),
                  itemCount: banks.length,
                  itemBuilder: (context, index) {
                    final bank = banks[index];
                    final rate = bank.fdRates[_selectedDurationKey] ?? 0.0;
                    return InkWell(
                      onTap: () => context.go('/bank/${Uri.encodeComponent(bank.name)}'),
                      borderRadius: BorderRadius.circular(16),
                      child: _buildBankCard(
                        bank.name,
                        bank.type.toUpperCase(),
                        '${rate.toStringAsFixed(2)}%',
                        index == 0,
                        Theme.of(context).primaryColor,
                        emerald,
                        isDark,
                      ),
                    );
                  },
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

  Widget _buildBankCard(String name, String type, String rate, bool isHighest, Color gold, Color emerald, bool isDark) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(0),
      child: Container(
        decoration: isHighest ? BoxDecoration(
          border: Border.all(color: gold, width: 2),
          borderRadius: BorderRadius.circular(16),
        ) : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF243447) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (isHighest) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.stars, color: gold, size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(type, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(rate, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isHighest ? emerald : (isDark ? Colors.white : Colors.black87))),
                  const Text('p.a.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
