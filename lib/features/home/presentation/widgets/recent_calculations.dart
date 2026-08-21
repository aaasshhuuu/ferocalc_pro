import 'package:flutter/material.dart';

class RecentCalculations extends StatelessWidget {
  const RecentCalculations({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.calculate)),
            title: const Text('Home Loan EMI'),
            subtitle: const Text('₹50,00,000 for 20 Yrs'),
            trailing: const Text('₹43,333/mo', style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {},
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.account_balance)),
            title: const Text('Fixed Deposit'),
            subtitle: const Text('₹1,00,000 for 1 Yr'),
            trailing: const Text('₹1,07,100', style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
