import 'package:flutter/material.dart';

class AppTheme {
  // ============================================================
  // PRIMARY COLORS
  // ============================================================

  // Midnight Emerald - Dark Mode
  static const Color primaryColor = Color(0xFF00C896);
  static const Color primaryDark = Color(0xFF009B75);
  static const Color accentColor = Color(0xFF7CFFCB);

  // ============================================================
  // STATUS COLORS
  // ============================================================

  static const Color successColor = Color(0xFF00C896);
  static const Color errorColor = Color(0xFFFF5C5C);
  static const Color warningColor = Color(0xFFFFB547);

  // ============================================================
  // DARK MODE COLORS
  // ============================================================

  static const Color bgDark = Color(0xFF071412);
  static const Color surfaceDark = Color(0xFF0D211D);
  static const Color cardDark = Color(0xFF102A24);

  static const Color textPrimaryDark = Color(0xFFF5FFFC);
  static const Color textSecondaryDark = Color(0xFF8FA8A1);

  static const Color dividerDark = Color(0xFF1C3A33);

  // ============================================================
  // LIGHT MODE COLORS
  // ============================================================

  static const Color bgLight = Color(0xFFF5FAF9);
  static const Color bgWhite = Colors.white;
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF102522);
  static const Color textSecondary = Color(0xFF647875);

  static const Color dividerColor = Color(0xFFD8E8E4);

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,

        secondary: accentColor,
        onSecondary: textPrimary,

        surface: surfaceLight,
        onSurface: textPrimary,

        error: errorColor,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: bgLight,

      // --------------------------------------------------------
      // APP BAR
      // --------------------------------------------------------

      appBarTheme: const AppBarTheme(
        backgroundColor: bgWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),

      // --------------------------------------------------------
      // CARD
      // --------------------------------------------------------

      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(16),
          ),
          side: BorderSide(
            color: dividerColor,
            width: 1,
          ),
        ),
      ),

      // --------------------------------------------------------
      // ELEVATED BUTTON
      // --------------------------------------------------------

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),

          elevation: 0,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // --------------------------------------------------------
      // OUTLINED BUTTON
      // --------------------------------------------------------

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,

          side: const BorderSide(
            color: primaryColor,
            width: 1.5,
          ),

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // --------------------------------------------------------
      // TEXT BUTTON
      // --------------------------------------------------------

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),

      // --------------------------------------------------------
      // INPUT
      // --------------------------------------------------------

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgWhite,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: dividerColor,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: dividerColor,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // --------------------------------------------------------
      // ICON
      // --------------------------------------------------------

      iconTheme: const IconThemeData(
        color: primaryColor,
      ),

      // --------------------------------------------------------
      // DIVIDER
      // --------------------------------------------------------

      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
      ),
    );
  }

  // ============================================================
  // DARK THEME
  // ============================================================

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: bgDark,

        secondary: accentColor,
        onSecondary: bgDark,

        surface: surfaceDark,
        onSurface: textPrimaryDark,

        error: errorColor,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: bgDark,

      // --------------------------------------------------------
      // APP BAR
      // --------------------------------------------------------

      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: false,
      ),

      // --------------------------------------------------------
      // CARD
      // --------------------------------------------------------

      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(16),
          ),
          side: BorderSide(
            color: dividerDark,
            width: 1,
          ),
        ),
      ),

      // --------------------------------------------------------
      // ELEVATED BUTTON
      // --------------------------------------------------------

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: bgDark,

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),

          elevation: 0,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // --------------------------------------------------------
      // OUTLINED BUTTON
      // --------------------------------------------------------

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,

          side: const BorderSide(
            color: primaryColor,
            width: 1.5,
          ),

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // --------------------------------------------------------
      // TEXT BUTTON
      // --------------------------------------------------------

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
        ),
      ),

      // --------------------------------------------------------
      // INPUT
      // --------------------------------------------------------

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: dividerDark,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: dividerDark,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // --------------------------------------------------------
      // ICON
      // --------------------------------------------------------

      iconTheme: const IconThemeData(
        color: primaryColor,
      ),

      // --------------------------------------------------------
      // DIVIDER
      // --------------------------------------------------------

      dividerTheme: const DividerThemeData(
        color: dividerDark,
        thickness: 1,
      ),
    );
  }
}