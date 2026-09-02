import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Colori del marchio HIO, presi dai token del sito hiooriental.com
  // (`assets/css/variables.css` e `design-system/MASTER.md`): gestionale,
  // modulo di prenotazione e sito devono sembrare la stessa cosa.
  //
  // Rispetto a prima cambia soprattutto la temperatura: dove c'erano grigi
  // neutri ora ci sono beige. Il grigio accanto all'oro del marchio lo
  // faceva sembrare sporco.
  static const background = Color(0xFFF5F0E7);      // Fondo caldo di pagina
  static const surface = Color(0xFFFFFDF8);         // Bianco caldo, schede e barre
  static const card = Color(0xFFFFFDF8);
  static const surfaceElevated = Color(0xFFFFFFFF); // Bianco pieno, in evidenza
  static const cardLight = Color(0xFFEFE8DA);       // Tinta sotto le schede

  // Inchiostro delle fasce in alto e in basso.
  static const nero = Color(0xFF160E0A);

  // Accent
  static const accent = Color(0xFFB9172A);          // Rosso HIO
  static const accentDark = Color(0xFF8E1220);
  static const accentLight = Color(0xFFFBEAE9);     // Rosso chiaro per sfondi

  // Oro
  static const gold = Color(0xFFCAB16F);            // Oro HIO
  static const goldLight = Color(0xFFF8F1E1);       // Oro chiaro per sfondi
  // L'oro HIO su fondo chiaro sta intorno a 2,2:1, sotto il minimo leggibile
  // di 4,5:1. Per i testi piccoli si usa questa versione scura (~5,4:1),
  // lasciando l'oro pieno a bordi, filetti e riempimenti. Anche il sito
  // dichiara di non usare mai l'oro come testo su bianco.
  static const goldDark = Color(0xFF8A6D1F);        // Oro scuro per i testi

  // Testi
  static const textPrimary = Color(0xFF18130F);     // Inchiostro
  static const textSecondary = Color(0xFF655D54);   // Bruno attenuato
  // Era #999999, circa 2,8:1: sotto il minimo leggibile. Questo sta sopra
  // 4,5:1 sul fondo caldo e resta comunque chiaramente secondario.
  static const textMuted = Color(0xFF7C7366);

  // UI
  static const divider = Color(0xFFD9CCB7);         // Filetto caldo
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
  // Fondo della riga di chi e' seduto. Tenue apposta: sopra ci passa il testo
  // normale, che sull'azzurro pieno non si leggerebbe.
  static const statoAlTavoloSfondo = Color(0xFFE4EEF6);
  static const statoConfermatoSfondo = Color(0xFFEAF5EF);
  static const statoAnnullatoSfondo = accentLight;
}

class AppTheme {
  /// La coppia tipografica del sito: Fraunces per i titoli, Manrope per il
  /// testo corrente.
  ///
  /// Prima erano Playfair Display SC e Karla. Fraunces ha grazie a cuneo ma
  /// aste piene, quindi regge anche in piccolo su schermo, dove i filetti
  /// sottili dei serif classici si spezzano. Manrope è geometrica e sta bene
  /// accanto al lettering sottile del logo.
  ///
  /// Playfair era in versione *small caps*: scriveva "Calendario" e si
  /// leggeva "CALENDARIO". Fraunces non lo fa, quindi i titoli delle barre
  /// ora appaiono come sono scritti.
  static TextTheme _testo(TextTheme base) {
    final corpo = GoogleFonts.manropeTextTheme(base);
    TextStyle titolo(TextStyle? s) => GoogleFonts.fraunces(
          textStyle: s,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        );
    return corpo.copyWith(
      displayLarge: titolo(base.displayLarge),
      displayMedium: titolo(base.displayMedium),
      displaySmall: titolo(base.displaySmall),
      headlineLarge: titolo(base.headlineLarge),
      headlineMedium: titolo(base.headlineMedium),
      headlineSmall: titolo(base.headlineSmall),
      titleLarge: titolo(base.titleLarge),
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
      titleTextStyle: GoogleFonts.fraunces(
        color: AppColors.accent,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
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
      titleTextStyle: GoogleFonts.fraunces(
          color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w600),
      contentTextStyle: GoogleFonts.manrope(color: AppColors.textPrimary),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
    ),
    useMaterial3: true,
  );
}
