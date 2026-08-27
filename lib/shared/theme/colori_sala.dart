import 'package:flutter/material.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

/// Un colore per ogni sala, uguale in tutte le schermate.
///
/// La regola è una sola: **il colore dice la sala, non lo stato.** Lo stato
/// resta affare dell'oro e del rosso del marchio, sui blocchi delle
/// prenotazioni. Se il colore facesse tutte e due le cose, una prenotazione
/// rossa nel dehors non si distinguerebbe da una sala chiamata rossa.
///
/// Le tinte sono desaturate e lontane dal rosso `#B7182A` e dall'oro
/// `#C9B06E` proprio per non rubare loro il significato. Dehors verde perché
/// è fuori, interno blu perché è dentro: si ricordano da soli.
class ColoriSala {
  /// Pieno: barre di intestazione, bande laterali, testo sui fondi chiari.
  final Color forte;

  /// Tinta leggera per il fondo delle righe della sala.
  final Color tinta;

  /// Icona che accompagna il nome nella barra.
  final IconData icona;

  const ColoriSala(this.forte, this.tinta, this.icona);

  /// Sul `forte` il testo va bianco: sono tutti scuri abbastanza.
  Color get suForte => Colors.white;

  /// Mezza tinta, per il fondo della griglia oraria.
  ///
  /// Piu' chiara di `tinta` perche' li' sopra ci passano le bande delle ore
  /// e i blocchi delle prenotazioni: se fosse carica come la colonna dei
  /// numeri, si sommerebbe a tutto il resto e tornerebbe il pastone.
  Color get tintaGriglia =>
      Color.alphaBlend(tinta.withValues(alpha: 0.5), AppColors.surface);

  static const _bancone = ColoriSala(
      Color(0xFF0F6E56), Color(0xFFE8F4F0), Icons.local_bar_outlined);
  static const _dehors = ColoriSala(
      Color(0xFF3B6D11), Color(0xFFEDF3E4), Icons.wb_sunny_outlined);
  static const _interno = ColoriSala(
      Color(0xFF185FA5), Color(0xFFE9F1FA), Icons.chair_outlined);
  static const _altro = ColoriSala(
      Color(0xFF5F5E5A), Color(0xFFF1EFE8), Icons.crop_square_outlined);

  /// Senza tavolo assegnato non è una sala: resta l'oro dell'attenzione.
  static const senzaTavolo = ColoriSala(
      AppColors.goldDark, AppColors.goldLight, Icons.error_outline);

  /// Il colore di una sala dal suo nome.
  ///
  /// Il confronto è sul nome perché le aree le crea il ristorante da
  /// Impostazioni: legarsi agli identificativi vorrebbe dire riscrivere il
  /// codice ogni volta che ne nasce una. Quelle sconosciute prendono il
  /// grigio ardesia, che non è un errore ma una sala ancora senza carattere.
  static ColoriSala di(String? nomeArea) {
    final n = (nomeArea ?? '').trim().toUpperCase();
    if (n.contains('BANCONE') || n.contains('BAR')) return _bancone;
    if (n.contains('DEHORS') || n.contains('ESTERNO')) return _dehors;
    if (n.contains('INTERNO') || n.contains('SALA')) return _interno;
    return _altro;
  }
}
