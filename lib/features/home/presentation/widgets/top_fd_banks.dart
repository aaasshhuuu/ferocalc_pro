import 'package:flutter/material.dart';
import '../../../../core/widgets/premium_badge.dart';

class TopFdBanks extends StatelessWidget {
  const TopFdBanks({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Text('\${index + 1}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
            title: Text('Bank \${index + 1}'),
            subtitle: const Text('General Citizen'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('\${7.5 - (index * 0.1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (index == 0) const SizedBox(width: 8),
                if (index == 0) const PremiumBadge(),
              ],
            ),
          ),
        );
      }),
    );
  }
}
