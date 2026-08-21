import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  static TextStyle get inter => GoogleFonts.inter();

  static TextStyle h1 = inter.copyWith(fontSize: 32, fontWeight: FontWeight.bold);
  static TextStyle h2 = inter.copyWith(fontSize: 24, fontWeight: FontWeight.bold);
  static TextStyle h3 = inter.copyWith(fontSize: 20, fontWeight: FontWeight.w600);
  static TextStyle h4 = inter.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle heading3 = h3;
  
  static TextStyle bodyLarge = inter.copyWith(fontSize: 16, fontWeight: FontWeight.normal);
  static TextStyle bodyMedium = inter.copyWith(fontSize: 14, fontWeight: FontWeight.normal);
  static TextStyle bodyText = bodyMedium;
  static TextStyle bodySmall = inter.copyWith(fontSize: 12, fontWeight: FontWeight.normal);
  
  static TextStyle labelLarge = inter.copyWith(fontSize: 14, fontWeight: FontWeight.w600);
  static TextStyle labelMedium = inter.copyWith(fontSize: 12, fontWeight: FontWeight.w500);
  static TextStyle labelSmall = inter.copyWith(fontSize: 10, fontWeight: FontWeight.w500);
}
