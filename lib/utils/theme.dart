import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeType { defaultDark, parkside }

class AppThemeColors {
  final Color primary;
  final Color primaryDark;
  final Color background;
  final Color surface;
  final Color myMessage;
  final Color otherMessage;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color accentText;
  final Color success;
  final Color error;
  final Color warning;

  const AppThemeColors({
    required this.primary,
    required this.primaryDark,
    required this.background,
    required this.surface,
    required this.myMessage,
    required this.otherMessage,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.accentText,
    required this.success,
    required this.error,
    required this.warning,
  });

  static AppThemeColors getColors(AppThemeType type) {
    switch (type) {
      case AppThemeType.parkside:
        return const AppThemeColors(
          primary: Color(0xFFAD251E),
          primaryDark: Color(0xFF8B1E18),
          background: Color(0xFF121212),
          surface: Color(0xFF1E1E1E),
          myMessage: Color(0xFF26543D),
          otherMessage: Color(0xFF2C2C2C),
          textPrimary: Color(0xFFFFFFFF),
          textSecondary: Color(0xFF8E8E93),
          border: Color(0xFF38383A),
          accentText: Color(0xFFFFFFFF),
          success: Color(0xFF34C759),
          error: Color(0xFFAD251E),
          warning: Color(0xFFFF9500),
        );
      case AppThemeType.defaultDark:
      default:
        return const AppThemeColors(
          primary: Color(0xFFA1E44D),
          primaryDark: Color(0xFF8FCC42),
          background: Color(0xFF212121),
          surface: Color(0xFF2C2C2C),
          myMessage: Color(0xFFA1E44D),
          otherMessage: Color(0xFF424242),
          textPrimary: Color(0xFFFFFFFF),
          textSecondary: Color(0xFF8E8E93),
          border: Color(0xFF38383A),
          accentText: Color(0xFF305700),
          success: Color(0xFF34C759),
          error: Color(0xFFFF3B30),
          warning: Color(0xFFFF9500),
        );
    }
  }
}

class AppTheme {
  static ThemeData getTheme(AppThemeType type) {
    final colors = AppThemeColors.getColors(type);
    
    // Choose font based on theme
    final textTheme = type == AppThemeType.parkside
        ? GoogleFonts.libreFranklinTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.dark(
        primary: colors.primary,
        surface: colors.surface,
        error: colors.error,
        onPrimary: colors.accentText,
      ),
      textTheme: textTheme,
      
      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.accentText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      
      // Icon Theme
      iconTheme: IconThemeData(
        color: colors.textSecondary,
        size: 24,
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.background,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}