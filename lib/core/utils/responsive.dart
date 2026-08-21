import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1024;
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= 1024;
  
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  
  static EdgeInsets screenPadding(BuildContext context) {
    if (isDesktop(context)) return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    if (isTablet(context)) return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
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
}
