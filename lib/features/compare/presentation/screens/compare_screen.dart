import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/data/bank_rate_repository.dart';
import '../../../../core/models/bank.dart';
import '../../../../core/models/fd_rate.dart';
import '../../../../core/widgets/fd_rate_card.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../core/utils/financial_math.dart';
import '../../../../core/utils/responsive.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({Key? key}) : super(key: key);

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  // Filter state
  int _tenureDays = 365;
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = const Color(0xFFC9A96E);

    // Get filtered rates
    final comparison = BankRateRepository.compareRates(
      tenureDays: _tenureDays,
      customerType: _customerType,
    );

    // Further filter by bank type
    final filtered = _selectedBankType == 'All'
        ? comparison
        : comparison.where((entry) {
            final bank = entry['bank'] as Bank?;
            if (bank == null) return false;
            return bank.typeLabel.toLowerCase().contains(_selectedBankType.toLowerCase());
          }).toList();

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[50],
      appBar: const CustomAppBar(title: 'Compare FD Rates', showBackButton: false),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                // Filters
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
                      // Customer Type Toggle
                      Row(
                        children: [
                          Text('Customer Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                          const Spacer(),
                          SegmentedButton<CustomerType>(
                            segments: const [
                              ButtonSegment(value: CustomerType.regular, label: Text('Regular', style: TextStyle(fontSize: 12))),
                              ButtonSegment(value: CustomerType.seniorCitizen, label: Text('Senior', style: TextStyle(fontSize: 12))),
                            ],
                            selected: {_customerType},
                            onSelectionChanged: (v) => setState(() => _customerType = v.first),
                            style: ButtonStyle(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Bank Type
                      Text('Bank Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _bankTypes.map((type) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(type, style: const TextStyle(fontSize: 12)),
                              selected: _selectedBankType == type,
                              selectedColor: gold.withOpacity(0.2),
                              labelStyle: TextStyle(color: _selectedBankType == type ? gold : (isDark ? Colors.white70 : Colors.black87)),
                              onSelected: (_) => setState(() => _selectedBankType = type),
                            ),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tenure Selector
                      Text('Tenure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      Row(
                        children: _tenureOptions.entries.map((e) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              onTap: () => setState(() => _tenureDays = e.value),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _tenureDays == e.value ? gold : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _tenureDays == e.value ? gold : (isDark ? Colors.white24 : Colors.black26)),
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
                      const SizedBox(height: 12),

                      // Deposit amount
                      Row(
                        children: [
                          Text('Deposit: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          Text(
                            FinancialMath.formatCurrencyRounded(_depositAmount),
                            style: TextStyle(fontSize: 13, color: gold, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(activeTrackColor: gold, thumbColor: gold, inactiveTrackColor: gold.withOpacity(0.2)),
                        child: Slider(
                          value: _depositAmount,
                          min: 10000,
                          max: 10000000,
                          divisions: 100,
                          onChanged: (v) => setState(() => _depositAmount = v),
                        ),
                      ),

                      // Summary
                      Row(
                        children: [
                          Text(
                            '${filtered.length} rates found',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                          ),
                          const Spacer(),
                          const VerificationBadge(status: VerificationStatus.pendingReview, compact: false),
                        ],
                      ),
                    ],
                  ),
                ),

                // Results
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                              const SizedBox(height: 16),
                              Text('No rates found for this criteria', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: Responsive.screenPadding(context),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            final bank = entry['bank'] as Bank?;
                            final rate = entry['rate'] as FdRate;
                            if (bank == null) return const SizedBox.shrink();

                            return FdRateCard(
                              bank: bank,
                              rate: rate,
                              onTap: () => context.go('/bank/\${Uri.encodeComponent(bank.name)}'),
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
}
