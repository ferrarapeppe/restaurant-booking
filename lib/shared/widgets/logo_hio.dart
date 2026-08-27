import 'package:flutter/material.dart';

/// Il logo HIO, sempre nitido.
///
/// In giro per l'app c'erano tre copie rimpicciolite dello stesso disegno —
/// `logo_appbar.png` era 268×68 — che sugli schermi densi venivano ingrandite
/// e sgranavano. Qui si parte sempre dall'originale a 2797×708 e si lascia
/// decodificare alla dimensione che serve davvero: `cacheWidth` tiene la
/// memoria bassa senza rinunciare alla nitidezza.
class LogoHio extends StatelessWidget {
  /// Larghezza voluta, oppure `altezza`: basta indicarne una.
  final double? larghezza;
  final double? altezza;

  const LogoHio({super.key, this.larghezza, this.altezza});

  /// Proporzioni dell'originale.
  static const double _rapporto = 2797 / 708;

  @override
  Widget build(BuildContext context) {
    final densita = MediaQuery.of(context).devicePixelRatio;
    final larghezzaVoluta = larghezza ??
        (altezza != null ? altezza! * _rapporto : 240.0);
    return Image.asset(
      'assets/images/HIO-ORIENTAL-BAR.png',
      width: larghezza,
      height: altezza,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      // Un po' di margine oltre la densità dello schermo: con lo zoom del
      // browser la stessa immagine può finire più grande del previsto.
      cacheWidth: (larghezzaVoluta * densita * 1.5).round().clamp(240, 2797),
    );
  }
}
