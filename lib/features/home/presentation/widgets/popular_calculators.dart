import 'package:flutter/material.dart';
import '../../../../config/themes/app_gradients.dart';

class PopularCalculators extends StatelessWidget {
  PopularCalculators({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> calculators = [
    {'name': 'EMI', 'icon': Icons.calculate},
    {'name': 'FD', 'icon': Icons.account_balance},
    {'name': 'SIP', 'icon': Icons.trending_up},
    {'name': 'PPF', 'icon': Icons.savings},
    {'name': 'RD', 'icon': Icons.timeline},
    {'name': 'Tax', 'icon': Icons.request_quote},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: calculators.length,
        itemBuilder: (context, index) {
          final item = calculators[index];
          return GestureDetector(
            onTap: () {},
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primaryDarkGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(item['icon'], color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(item['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
