// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData romanticTheme = ThemeData(
    // 1) Make Underdog the default everywhere
    fontFamily: GoogleFonts.underdog().fontFamily,

    // 2) Your textTheme (for body, etc.)
    textTheme: GoogleFonts.underdogTextTheme(
      const TextTheme(
        bodyLarge: TextStyle(color: AppColors.raspberryRose),
        titleLarge: TextStyle(
          color: AppColors.deepCherry,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    // 3) And specifically for AppBar titles (DefaultTextStyle inside AppBar)
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.deepCherry,
      elevation: 0,
      centerTitle: true,

      // supply only color/size/weight here—the fontFamily comes from global
      titleTextStyle: GoogleFonts.underdog(
        color: AppColors.white,   // or deepCherry if you prefer
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),

      // toolbarTextStyle covers things like actions if they ever use text
      toolbarTextStyle: GoogleFonts.underdog(
        textStyle: const TextStyle(color: AppColors.white),
      ),

      iconTheme: const IconThemeData(color: AppColors.rose),
    ),

    scaffoldBackgroundColor: Colors.transparent,

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.deepCherry,
      foregroundColor: AppColors.white,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.rose,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        // this textStyle still inherits the global fontFamily
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),

    iconTheme: const IconThemeData(color: AppColors.rose),

    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: AppColors.deepCherry,
      secondary: AppColors.rose,
    ),
  );
}
