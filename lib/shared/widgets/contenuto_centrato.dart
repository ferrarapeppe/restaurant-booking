import 'package:flutter/material.dart';

/// Tiene il contenuto a una larghezza leggibile e lo centra.
///
/// Le schermate sono nate per il telefono. Su un monitor largo, stirate da
/// bordo a bordo, moduli ed elenchi diventano lenzuoli: l'occhio deve
/// attraversare mezzo metro per collegare un'etichetta al suo valore.
///
/// Non va usato dove la larghezza serve davvero — la tabella delle
/// prenotazioni, la planimetria — perche' li' toglierebbe spazio utile.
class ContenutoCentrato extends StatelessWidget {
  final Widget child;
  final double larghezzaMassima;

  const ContenutoCentrato({
    super.key,
    required this.child,
    this.larghezzaMassima = 1040,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: larghezzaMassima),
          child: child,
        ),
      );
}

/// Quante colonne stanno comode alla larghezza data.
///
/// Due sul telefono, di piu' man mano che c'e' spazio: una griglia a due
/// colonne su un monitor produce riquadri enormi e mezzi vuoti.
int colonnePerLarghezza(double larghezza, {int minimo = 2, int massimo = 4}) {
  if (larghezza >= 1000) return massimo;
  if (larghezza >= 700) return (massimo - 1).clamp(minimo, massimo);
  return minimo;
}
