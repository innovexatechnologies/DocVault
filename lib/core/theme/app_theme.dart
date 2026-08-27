import 'package:flutter/material.dart';

class AppTheme {
  // ============================================================
  // BRAND COLORS
  // ============================================================

  static const Color primaryColor = Color(0xFF7C4DFF);
  static const Color primaryDark = Color(0xFF5E35B1);

  static const Color secondaryColor = Color(0xFF2979FF);
  static const Color accentColor = Color(0xFFC084FC);

  // ============================================================
  // CONVERSION COLORS
  // ============================================================

  static const Color pdfColor = Color(0xFFFF3D4F);
  static const Color pdfPink = Color(0xFFE91E63);

  static const Color docxColor = Color(0xFF2979FF);
  static const Color docxBlue = Color(0xFF3D5AFE);

  static const Color pptColor = Color(0xFFFF6D00);
  static const Color pptOrange = Color(0xFFFF8A00);

  // ============================================================
  // STATUS COLORS
  // ============================================================

  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFFF5252);
  static const Color warningColor = Color(0xFFFFB300);

  // ============================================================
  // DARK MODE
  // ============================================================

  static const Color bgDark = Color(0xFF050A1F);

  static const Color surfaceDark = Color(0xFF0B1028);

  static const Color cardDark = Color(0xFF11162F);

  static const Color cardDarkSecondary = Color(0xFF151A35);

  static const Color textPrimaryDark = Color(0xFFF8F9FF);

  static const Color textSecondaryDark = Color(0xFFAAB1C8);

  static const Color dividerDark = Color(0xFF252B48);

  // ============================================================
  // LIGHT MODE
  // ============================================================

  static const Color bgLight = Color(0xFFFDFDFF);

  static const Color bgWhite = Colors.white;

  static const Color surfaceLight = Color(0xFFFFFFFF);

  static const Color cardLight = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF111318);

  static const Color textSecondary = Color(0xFF626B80);

  static const Color dividerColor = Color(0xFFE5E7EF);

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      fontFamily: 'Roboto',

      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,

        secondary: secondaryColor,
        onSecondary: Colors.white,

        surface: surfaceLight,
        onSurface: textPrimary,

        error: errorColor,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: bgLight,

      // ========================================================
      // APP BAR
      // ========================================================

      appBarTheme: const AppBarTheme(
        backgroundColor: bgLight,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      // ========================================================
      // CARD
      // ========================================================

      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,

        margin: EdgeInsets.zero,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(22),
          ),

          side: BorderSide(
            color: dividerColor,
            width: 1,
          ),
        ),
      ),

      // ========================================================
      // ELEVATED BUTTON
      // ========================================================

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,

          elevation: 0,

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 15,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ========================================================
      // OUTLINED BUTTON
      // ========================================================

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
            borderRadius: BorderRadius.circular(16),
          ),

          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ========================================================
      // TEXT BUTTON
      // ========================================================

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,

          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ========================================================
      // INPUT
      // ========================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        fillColor: Colors.white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: dividerColor,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: dividerColor,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: errorColor,
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: errorColor,
            width: 2,
          ),
        ),
      ),

      // ========================================================
      // ICON
      // ========================================================

      iconTheme: const IconThemeData(
        color: primaryColor,
      ),

      // ========================================================
      // DIVIDER
      // ========================================================

      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      // ========================================================
      // NAVIGATION BAR
      // ========================================================

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,

        elevation: 0,

        indicatorColor: const Color(0xFFEDE7FF),

        labelTextStyle:
            WidgetStateProperty.resolveWith<TextStyle?>(
          (states) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w700,
              );
            }

            return const TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w500,
            );
          },
        ),

        iconTheme:
            WidgetStateProperty.resolveWith<IconThemeData?>(
          (states) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return const IconThemeData(
                color: primaryColor,
              );
            }

            return const IconThemeData(
              color: textSecondary,
            );
          },
        ),
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

      fontFamily: 'Roboto',

      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,

        secondary: secondaryColor,
        onSecondary: Colors.white,

        surface: surfaceDark,
        onSurface: textPrimaryDark,

        error: errorColor,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: bgDark,

      // ========================================================
      // APP BAR
      // ========================================================

      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),

      // ========================================================
      // CARD
      // ========================================================

      cardTheme: CardThemeData(
        color: cardDark,

        elevation: 0,

        margin: EdgeInsets.zero,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(22),
          ),

          side: BorderSide(
            color: dividerDark,
            width: 1,
          ),
        ),
      ),

      // ========================================================
      // ELEVATED BUTTON
      // ========================================================

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,

          foregroundColor: Colors.white,

          elevation: 0,

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 15,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ========================================================
      // OUTLINED BUTTON
      // ========================================================

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,

          side: const BorderSide(
            color: primaryColor,
            width: 1.5,
          ),

          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ========================================================
      // TEXT BUTTON
      // ========================================================

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,

          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ========================================================
      // INPUT
      // ========================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        fillColor: surfaceDark,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: dividerDark,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: dividerDark,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: errorColor,
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: const BorderSide(
            color: errorColor,
            width: 2,
          ),
        ),
      ),

      // ========================================================
      // ICON
      // ========================================================

      iconTheme: const IconThemeData(
        color: accentColor,
      ),

      // ========================================================
      // DIVIDER
      // ========================================================

      dividerTheme: const DividerThemeData(
        color: dividerDark,
        thickness: 1,
        space: 1,
      ),

      // ========================================================
      // NAVIGATION BAR
      // ========================================================

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0A0F27),

        elevation: 0,

        indicatorColor: const Color(0xFF211A4A),

        labelTextStyle:
            WidgetStateProperty.resolveWith<TextStyle?>(
          (states) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return const TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w700,
              );
            }

            return const TextStyle(
              color: textSecondaryDark,
              fontWeight: FontWeight.w500,
            );
          },
        ),

        iconTheme:
            WidgetStateProperty.resolveWith<IconThemeData?>(
          (states) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return const IconThemeData(
                color: accentColor,
              );
            }

            return const IconThemeData(
              color: textSecondaryDark,
            );
          },
        ),
      ),
    );
  }
}