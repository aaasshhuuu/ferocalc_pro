import 'package:flutter/material.dart';

class Responsive {
  static bool isCompact(BuildContext context) => MediaQuery.of(context).size.width <= 340;
  static bool isSmallMobile(BuildContext context) => MediaQuery.of(context).size.width <= 375;
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1024;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1024;

  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;

  static bool prefersReducedMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static EdgeInsets screenPadding(BuildContext context) {
    if (isDesktop(context)) return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    if (isTablet(context)) return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    if (isCompact(context)) return const EdgeInsets.symmetric(horizontal: 10, vertical: 12);
    return const EdgeInsets.all(16);
  }

  static EdgeInsets cardPadding(BuildContext context) {
    if (isCompact(context)) return const EdgeInsets.all(12);
    if (isDesktop(context)) return const EdgeInsets.all(20);
    return const EdgeInsets.all(16);
  }

  static double maxContentWidth(BuildContext context, {double maxWidth = 800}) {
    return screenWidth(context) > maxWidth ? maxWidth : screenWidth(context);
  }

  static int gridCrossAxisCount(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 3}) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  static double adaptiveDialogWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width <= 340) return width * 0.94;
    if (width < 600) return width * 0.90;
    return 480;
  }
}
