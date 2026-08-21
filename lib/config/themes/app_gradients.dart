import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradients {
  static const Gradient primaryDarkGradient = LinearGradient(
    colors: [AppColors.midnight, AppColors.charcoal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient primaryLightGradient = LinearGradient(
    colors: [AppColors.lightBg, AppColors.lightSurface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient cardGlassGradient = LinearGradient(
    colors: [
      Color(0x1AFFFFFF),
      Color(0x05FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const Gradient successGradient = LinearGradient(
    colors: [AppColors.emerald, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient goldGradient = LinearGradient(
    colors: [Color(0xFFC9A96E), Color(0xFFE5C07B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient tealGradient = LinearGradient(
    colors: [AppColors.teal, AppColors.tealLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
