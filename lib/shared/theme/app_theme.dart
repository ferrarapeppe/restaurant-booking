import 'package:flutter/material.dart';

class AppColors {
  // Colori principali HIO
  static const background = Color(0xFFFFFFFF);      // Bianco
  static const surface = Color(0xFFF8F8F8);         // Grigio chiarissimo
  static const card = Color(0xFFFFFFFF);
  static const cardLight = Color(0xFFF2F2F2);

  // Accent
  static const accent = Color(0xFFB7182A);          // Rosso HIO
  static const accentDark = Color(0xFF8F1220);
  static const accentLight = Color(0xFFFDECED);     // Rosso chiaro per sfondi

  // Oro
  static const gold = Color(0xFFC9B06E);            // Oro HIO
  static const goldLight = Color(0xFFFBF7EE);       // Oro chiaro per sfondi

  // Testi
  static const textPrimary = Color(0xFF1A1A1A);     // Quasi nero
  static const textSecondary = Color(0xFF555555);   // Grigio medio
  static const textMuted = Color(0xFF999999);       // Grigio chiaro

  // UI
  static const divider = Color(0xFFE0E0E0);
  static const badgeGreen = Color(0xFF28A745);
  static const accentGreen = Color(0xFF28A745);
  static const badgeGrey = Color(0xFF6B7280);
  static const closed = Color(0xFFEF4444);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      secondary: AppColors.gold,
      surface: AppColors.surface,
      background: AppColors.background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.accent,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardTheme(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: AppColors.accent,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.accent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.textPrimary,
      iconColor: AppColors.accent,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dialogTheme: const DialogTheme(
      backgroundColor: AppColors.surface,
      titleTextStyle: TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.bold),
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
    ),
    useMaterial3: true,
  );
}
