import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0A1628), // Dark navy
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF0A1628),
      primary: Color(0xFFC9A96E), // Gold accent
      secondary: Color(0xFF00B4D8), // Teal accent
      onSurface: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF000000),
      error: Color(0xFFEF4444),
    ),
    cardColor: const Color(0xFF0F1F35), // Slightly lighter navy for cards
    cardTheme: CardTheme(
      color: const Color(0xFF0F1F35),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A1628),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: Color(0xFFC9A96E)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF0A1628),
      selectedItemColor: Color(0xFFC9A96E),
      unselectedItemColor: Color(0xFF666666),
    ),
    dividerColor: const Color(0xFF222222),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: Color(0xFFAAAAAA), fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Color(0xFFDDDDDD)),
      bodySmall: TextStyle(color: Color(0xFF888888)),
      labelLarge: TextStyle(color: Color(0xFFC9A96E), fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F1F35),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF333333))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF333333))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFC9A96E))),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0xFFC9A96E),
      inactiveTrackColor: Color(0xFF333333),
      thumbColor: Color(0xFFC9A96E),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Color(0xFFC9A96E),
      unselectedLabelColor: Color(0xFF888888),
      indicatorColor: Color(0xFFC9A96E),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF5F7FA), // subtle blue-grey tint
    colorScheme: const ColorScheme.light(
      surface: Color(0xFFF5F7FA),
      primary: Color(0xFF1A5276), // Deep navy blue
      secondary: Color(0xFF0097A7), // Teal
      onSurface: Color(0xFF1A1A1A),
      onPrimary: Color(0xFFFFFFFF),
      error: Color(0xFFDC3545),
    ),
    cardColor: const Color(0xFFFFFFFF), // Pure white cards
    cardTheme: CardTheme(
      color: const Color(0xFFFFFFFF),
      elevation: 1,
      shadowColor: Color(0x14000000), // Colors.black.withOpacity(0.08)
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: Color(0xFF1A1A1A), fontSize: 18, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: Color(0xFF1A5276)),
      shape: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFFFFFFF),
      selectedItemColor: Color(0xFF1A5276),
      unselectedItemColor: Color(0xFF999999),
    ),
    dividerColor: const Color(0xFFE5E7EB),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: Color(0xFF666666), fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
      bodyMedium: TextStyle(color: Color(0xFF444444)),
      bodySmall: TextStyle(color: Color(0xFF888888)),
      labelLarge: TextStyle(color: Color(0xFF1A5276), fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF0F2F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A5276))),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Color(0xFF1A5276),
      inactiveTrackColor: Color(0xFFE5E7EB),
      thumbColor: Color(0xFF1A5276),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Color(0xFF1A5276),
      unselectedLabelColor: Color(0xFF999999),
      indicatorColor: Color(0xFF1A5276),
    ),
  );
}
