import 'package:flutter/material.dart';

class AppColors {
  // Colori principali HIO
  static const background = Color(0xFF202020);      // Fondo grigio scuro
  static const surface = Color(0xFF2A2A2A);         // Superficie card
  static const card = Color(0xFF2A2A2A);
  static const cardLight = Color(0xFF333333);

  // Accent
  static const accent = Color(0xFFB7182A);          // Rosso HIO
  static const accentDark = Color(0xFF8F1220);
  static const accentLight = Color(0xFF3A1A1E);     // Rosso scuro per sfondi

  // Oro
  static const gold = Color(0xFFC9B06E);            // Oro HIO
  static const goldLight = Color(0xFF3A3020);       // Oro scuro per sfondi

  // Testi
  static const textPrimary = Color(0xFFFFFFFF);     // Bianco
  static const textSecondary = Color(0xFFB0B0B0);   // Grigio chiaro
  static const textMuted = Color(0xFF707070);       // Grigio scuro

  // UI
  static const divider = Color(0xFF3A3A3A);
  static const badgeGreen = Color(0xFF28A745);
  static const accentGreen = Color(0xFF28A745);
  static const badgeGrey = Color(0xFF6B7280);
  static const closed = Color(0xFFEF4444);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.gold,
      surface: AppColors.surface,
      background: AppColors.background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.gold,
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
      labelColor: AppColors.gold,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.gold,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.textPrimary,
      iconColor: AppColors.gold,
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
        borderSide: const BorderSide(color: AppColors.gold, width: 2),
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
      titleTextStyle: TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.bold),
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
    ),
    useMaterial3: true,
  );
}
