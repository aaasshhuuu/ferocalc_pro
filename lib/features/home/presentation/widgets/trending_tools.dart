import 'package:flutter/material.dart';
import '../../../../core/widgets/glassmorphic_card.dart';

class TrendingTools extends StatelessWidget {
  const TrendingTools({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildToolCard(context, 'Retirement Planner', Icons.beach_access),
          _buildToolCard(context, 'Goal Planner', Icons.flag),
          _buildToolCard(context, 'Stock Return', Icons.show_chart),
        ],
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, String title, IconData icon) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      child: GlassmorphicCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
