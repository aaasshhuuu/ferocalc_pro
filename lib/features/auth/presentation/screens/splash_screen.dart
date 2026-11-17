import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/route_names.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.goNamed(RouteNames.home);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final backgroundColor = isDark ? Theme.of(context).scaffoldBackgroundColor : colorScheme.surface;
    const primaryGold = Color(0xFFC9A96E);
    const secondaryGold = Color(0xFFE8D399);
    const tealAccent = Color(0xFF00B4D8);
    final textColor = isDark ? primaryGold : colorScheme.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [primaryGold, secondaryGold],
              ).createShader(bounds),
              child: const Icon(Icons.calculate_rounded, size: 120, color: Colors.white),
            ).animate()
              
              ,
            const SizedBox(height: 24),
            Text(
              'FeroCalc',
              style: TextStyle(
                color: textColor,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ).animate()
              .fade(duration: 300.ms, )
              ,
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 2,
              color: tealAccent,
            ).animate()
              .scaleX(duration: 300.ms, curve: Curves.easeInOut),
          ],
        ),
      ),
    );
  }
}
