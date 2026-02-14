import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ChatGPT-style dark theme for AURA Mobile
class AppTheme {
  AppTheme._();

  // ── Core Palette ──
  static const Color background = Color(0xFF212121);
  static const Color sidebar = Color(0xFF171717);
  static const Color surface = Color(0xFF2F2F2F);
  static const Color inputBg = Color(0xFF2F2F2F);
  static const Color userBubble = Color(0xFF2F2F2F);
  static const Color accent = Color(0xFF10A37F);

  // ── Text Colors ──
  static const Color textPrimary = Color(0xFFECECEC);
  static const Color textSecondary = Color(0xFF9B9B9B);
  static const Color textMuted = Color(0xFF6B6B6B);

  // ── Surface Variants ──
  static const Color surfaceLight = Color(0xFF3A3A3A);
  static const Color border = Color(0xFF3A3A3A);
  static const Color divider = Color(0xFF2A2A2A);

  // ── Semantic Colors ──
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10A37F);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: sidebar,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textSecondary),
      ),
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          bodyLarge: TextStyle(color: textPrimary),
          bodyMedium: TextStyle(color: textPrimary),
          bodySmall: TextStyle(color: textSecondary),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          labelLarge: TextStyle(color: textPrimary),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: divider,
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
      ),
      useMaterial3: true,
    );
  }
}
