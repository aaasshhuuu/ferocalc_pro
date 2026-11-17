import 'package:flutter/material.dart';

class QuickSearch extends StatelessWidget {
  const QuickSearch({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Search calculators, banks...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
