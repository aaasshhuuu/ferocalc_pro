import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedCard extends StatelessWidget {
  final Widget child;
  final int delayMs;
  
  const AnimatedCard({
    Key? key, 
    required this.child,
    this.delayMs = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: child,
    ).animate()
      .fade(duration: 300.ms, delay: delayMs.ms)
      , duration: 300.ms, curve: Curves.easeOutBack);
  }
}
