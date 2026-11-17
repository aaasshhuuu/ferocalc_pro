import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedCard extends StatelessWidget {
  
  const AnimatedCard({
    Key? key, 
    required this.child,
    this.delayMs = 0,
  }) : super(key: key);
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final prefersReducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (prefersReducedMotion) {
      return Card(child: child);
    }

    return Card(
      child: child,
    ).animate()
      .fade(duration: 300.ms, delay: delayMs.ms)
      .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOutBack);
  }
}
