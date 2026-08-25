import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  // L'oro HIO su fondo chiaro sta intorno a 2,2:1, sotto il minimo leggibile
  // di 4,5:1. Per i testi piccoli si usa questa versione scura (~5,4:1),
  // lasciando l'oro pieno a bordi, filetti e riempimenti.
  static const goldDark = Color(0xFF8A6D1F);        // Oro scuro per i testi

  // Testi
  static const textPrimary = Color(0xFF1A1A1A);     // Quasi nero
  static const textSecondary = Color(0xFF555555);   // Grigio medio
  static const textMuted = Color(0xFF999999);       // Grigio chiaro

  // UI
  static const divider = Color(0xFFE0E0E0);
  static const badgeGreen = Color(0xFF2E7D52);
  static const accentGreen = Color(0xFF2E7D52);
  static const badgeGrey = Color(0xFF6B7280);
  static const closed = Color(0xFFB7182A);

  // ── Stati della prenotazione ────────────────────────────────────────────
  // Stesse tonalità che il cliente vede nella pagina di riepilogo, così
  // personale e cliente parlano lo stesso linguaggio visivo.
  static const statoAttesa = gold;                  // in attesa di conferma
  static const statoConfermato = Color(0xFF2E7D52); // confermata
  static const statoAlTavolo = Color(0xFF1B6B8F);   // al tavolo
  static const statoConcluso = Color(0xFF6B7280);   // conclusa
  static const statoAnnullato = accent;             // annullata, non presentato

  // Sfondi tenui abbinati, per pastiglie e riquadri di stato
  static const statoAttesaSfondo = goldLight;
  static const statoConfermatoSfondo = Color(0xFFEAF5EF);
  static const statoAnnullatoSfondo = accentLight;
}

class AppTheme {
  /// Stessa coppia tipografica del modulo di prenotazione e delle email:
  /// Playfair Display SC per i titoli, Karla per il testo corrente.
  static TextTheme _testo(TextTheme base) {
    final corpo = GoogleFonts.karlaTextTheme(base);
    return corpo.copyWith(
      displayLarge: GoogleFonts.playfairDisplaySc(textStyle: base.displayLarge, fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.playfairDisplaySc(textStyle: base.displayMedium, fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.playfairDisplaySc(textStyle: base.displaySmall, fontWeight: FontWeight.bold),
      headlineLarge: GoogleFonts.playfairDisplaySc(textStyle: base.headlineLarge, fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.playfairDisplaySc(textStyle: base.headlineMedium, fontWeight: FontWeight.bold),
      headlineSmall: GoogleFonts.playfairDisplaySc(textStyle: base.headlineSmall, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.playfairDisplaySc(textStyle: base.titleLarge, fontWeight: FontWeight.bold),
    );
  }

  static ThemeData get light {
    final base = ThemeData.light();
    return _componi(base);
  }

  static ThemeData _componi(ThemeData base) => ThemeData(
    brightness: Brightness.light,
    textTheme: _testo(base.textTheme),
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      secondary: AppColors.gold,
      surface: AppColors.surface,
      background: AppColors.background,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      // Gli stili in linea non ereditano dal textTheme: il font va indicato qui
      titleTextStyle: GoogleFonts.playfairDisplaySc(
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
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.surface,
      titleTextStyle: GoogleFonts.playfairDisplaySc(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.bold),
      contentTextStyle: GoogleFonts.karla(color: AppColors.textPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
    ),
    useMaterial3: true,
  );
}
