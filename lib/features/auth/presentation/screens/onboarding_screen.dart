import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../config/routes/route_names.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../config/themes/app_gradients.dart';
import '../../../../core/utils/responsive.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final primaryGold = const Color(0xFFC9A96E);
    final tealAccent = const Color(0xFF00B4D8);

    final pages = [
      _buildPage(Icons.calculate, 'Smart Financial Planning', 'Calculate EMI, FD, SIP in seconds.'),
      _buildPage(Icons.account_balance, 'Compare & Save', 'Compare FD rates across 30+ Indian banks.'),
      _buildPage(Icons.trending_up, 'Your Money, Your Way', 'Track, plan, and grow your wealth.'),
    ];

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Stack(
            children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: pages,
          ),
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: () => context.goNamed(RouteNames.home),
              child: Text('Skip', style: TextStyle(color: primaryGold, fontWeight: FontWeight.bold)),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) => _buildDot(index, primaryGold, tealAccent)),
                ),
                const SizedBox(height: 24),
                if (_currentPage == 2)
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      text: 'Get Started',
                      gradient: AppGradients.primaryDarkGradient,
                      onPressed: () => context.goNamed(RouteNames.home),
                    ).animate().fade(),
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(Icons.arrow_forward_ios, color: primaryGold),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ))),
    );
  }

  Widget _buildPage(IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 120, color: const Color(0xFFC9A96E)).animate(),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ).animate().fade(delay: 200.ms),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ).animate().fade(),
        ],
      ),
    );
  }

  Widget _buildDot(int index, Color activeColor, Color activeTeal) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? activeColor : Colors.grey.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
