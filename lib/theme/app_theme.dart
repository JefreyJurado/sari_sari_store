import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized brand + accent palette. Same hex values already used
/// throughout the app (kept unchanged by design) — this just gives every
/// screen one place to pull them from instead of redeclaring private
/// `const _blue = Color(0xFF1E3A8A)` constants file by file.
class AppColors {
  AppColors._();

  // Brand
  static const Color blue = Color(0xFF1E3A8A);
  static const Color blueDark = Color(0xFF152B66);
  static const Color blueLight = Color(0xFF3454A8);

  // Accents
  static const Color green = Color(0xFF059669);
  static const Color emerald = Color(0xFF10B981);
  static const Color orange = Color(0xFFEA580C);
  static const Color purple = Color(0xFF7C3AED);
  static const Color teal = Color(0xFF0891B2);
  static const Color pink = Color(0xFFDB2777);
  static const Color red = Color(0xFFDC2626);
  static const Color amber = Color(0xFFD97706);

  // Neutrals
  static const Color background = Color(0xFFF8FAFC);
  static const Color surfaceAlt = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
}

/// Consistent corner-radius scale. Pick the closest token instead of a
/// one-off number so cards, chips, and sheets read as one system.
class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 14;
  static const double xxl = 16;
  static const double sheet = 24;
  static const double pill = 30;
}

/// Consistent spacing scale.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

/// Shared shadow presets so elevation reads consistently across cards.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> colored(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          padding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 20),
        ),
      ),
    );
  }
}
