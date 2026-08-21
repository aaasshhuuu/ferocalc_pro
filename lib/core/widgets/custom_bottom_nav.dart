import 'package:flutter/material.dart';
import 'dart:ui';
import '../../config/themes/app_gradients.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        
        if (isDesktop) {
          // Instead of returning bottom nav, we return a Side Navigation Rail 
          // or a constrained area. Note: Normally SideRail is placed in the main Scaffold 
          // row, but since this widget might be dropped in bottomNavigationBar slot, 
          // we can just hide it for desktop and handle desktop nav elsewhere, 
          // OR we return a minimal vertical version if this wraps the body.
          // Since it's a bottom nav widget, hiding it is standard for desktop.
          return const SizedBox.shrink();
        }

        return ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(context, 0, Icons.home_rounded, 'Home'),
                      _buildNavItem(context, 1, Icons.calculate_rounded, 'Calculators'),
                      _buildNavItem(context, 2, Icons.compare_arrows_rounded, 'Compare'),
                      _buildNavItem(context, 3, Icons.insights_rounded, 'Insights'),
                      _buildNavItem(context, 4, Icons.person_rounded, 'Profile'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final theme = Theme.of(context).bottomNavigationBarTheme;
    final isSelected = currentIndex == index;
    final color = isSelected ? theme.selectedItemColor : theme.unselectedItemColor;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                icon, 
                key: ValueKey<bool>(isSelected), 
                color: color, 
                size: isSelected ? 26 : 24
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 4),
              height: 4,
              width: isSelected ? 4 : 0,
              decoration: BoxDecoration(
                color: theme.selectedItemColor,
                shape: BoxShape.circle,
              ),
            )
          ],
        ),
      ),
    );
  }
}
