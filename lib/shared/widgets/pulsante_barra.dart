import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Il pulsante a sinistra nella barra: indietro se si può tornare, altrimenti
/// il menu.
///
/// Prima ogni schermata metteva l'hamburger fisso. Funziona finché ci si
/// arriva dal menu, ma aprendo l'elenco da dentro il calendario non restava
/// nessuna strada per tornare indietro se non ripassare dal menu — e chi
/// stava guardando la settimana del 12 la ritrovava com'era all'inizio.
///
/// `canPop` risponde alla domanda giusta: c'è una schermata sotto questa?
/// Se sì la freccia la scopre, se no il menu è l'unica cosa sensata.
class PulsanteBarra extends StatelessWidget {
  /// Colore dell'icona: bianco sulle barre nere, scuro sulle chiare.
  final Color colore;
  final double misura;

  const PulsanteBarra({
    super.key,
    this.colore = Colors.white,
    this.misura = 24,
  });

  @override
  Widget build(BuildContext context) => Builder(
        builder: (ctx) => ctx.canPop()
            ? IconButton(
                tooltip: 'Indietro',
                icon: Icon(Icons.arrow_back, color: colore, size: misura),
                onPressed: () => ctx.pop(),
              )
            : IconButton(
                tooltip: 'Menu',
                icon: Icon(Icons.menu, color: colore, size: misura),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
      );
}
