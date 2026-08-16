import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Radar / Cyber-console color palette for Smart-Prep
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg = Color(0xFF090D16);
  static const Color surfaceSolid = Color(0xFF111827);
  static const Color surfaceElevated = Color(0xFF1F2937);
  static const Color surfaceGlass = Color(0x8C111827);

  // Borders
  static const Color border = Color(0xFF1F2E3D);
  static const Color borderSubtle = Color(0xFF16202C);

  // Radar Accent Greens
  static const Color green = Color(0xFF00E599);
  static const Color greenGlow = Color(0xFF54FFB5);
  static const Color greenDark = Color(0xFF056441);
  static const Color greenAccent = Color(0xFF10B981);

  // Text colors
  static const Color textMain = Color(0xFFF3F4F6);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFF4B5563);

  // Status colors
  static const Color error = Color(0xFFFF5353);
  static const Color warning = Color(0xFFFBBF24);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF38BDF8);
}

/// Typography styles using Google Fonts (Space Grotesk & JetBrains Mono)
class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading = GoogleFonts.spaceGrotesk(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
    letterSpacing: -0.5,
  );

  static TextStyle subheading = GoogleFonts.spaceGrotesk(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textMain,
  );

  static TextStyle body = GoogleFonts.spaceGrotesk(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textMain,
  );

  static TextStyle bodyBold = GoogleFonts.spaceGrotesk(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textMain,
  );

  static TextStyle mono = GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textMain,
  );

  static TextStyle monoBold = GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textMain,
  );

  static TextStyle button = GoogleFonts.spaceGrotesk(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static TextStyle label = GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: AppColors.textMuted,
  );
}

/// ThemeData generator for the Cyber / Radar Console Theme
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.green,
        onPrimary: Colors.black,
        surface: AppColors.surfaceSolid,
        onSurface: AppColors.textMain,
        error: AppColors.error,
        onError: Colors.black,
      ),
      fontFamily: GoogleFonts.spaceGrotesk().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceSolid,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.subheading,
        iconTheme: const IconThemeData(color: AppColors.green),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceSolid,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg.withValues(alpha: 0.7),
        hintStyle: AppTextStyles.mono.copyWith(color: AppColors.textMuted),
        labelStyle: AppTextStyles.body.copyWith(color: AppColors.greenGlow),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.green.withValues(alpha: 0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.green.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.green, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
    );
  }
}
