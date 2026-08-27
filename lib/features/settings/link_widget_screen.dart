import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/contenuto_centrato.dart';
import 'package:restaurant_booking/shared/widgets/pulsante_barra.dart';

/// Dove trovare l'indirizzo del modulo da dare ai clienti.
///
/// Sembra un'inezia finché lo sa a memoria chi ha costruito il sistema. Poi
/// entra qualcuno di nuovo in sala, un cliente chiede "dove prenoto?", e
/// quell'informazione non è scritta da nessuna parte nel gestionale.
class LinkWidgetScreen extends StatelessWidget {
  const LinkWidgetScreen({super.key});

  /// L'indirizzo pubblico del modulo. È fisso perché è l'indirizzo del sito
  /// pubblicato, non un'impostazione del ristorante.
  static const _link = 'https://prenota.hiooriental.com';

  /// La pagina dove il cliente ritrova la sua prenotazione. Finisce nelle
  /// email, ma capita di doverla mandare a mano a chi l'ha persa.
  static const _linkStato = 'https://prenota.hiooriental.com/booking-status.html';

  static const _codice = '<iframe src="https://prenota.hiooriental.com"\n'
      '        title="Prenota — Hio Oriental Bar"\n'
      '        width="100%" height="900" style="border:0"\n'
      '        loading="lazy"></iframe>';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: const PulsanteBarra(),
        title: const Text('Link e widget',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
      ),
      body: ContenutoCentrato(
        larghezzaMassima: 820,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const _Titolo('Il link per i clienti'),
          const SizedBox(height: 6),
          const Text(
            'Questo è l\'indirizzo da mettere su Instagram, su Google, nella '
            'firma delle email o su un cartoncino al tavolo. Apre il modulo '
            'di prenotazione.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          _Riquadro(
            testo: _link,
            grande: true,
            azioni: [
              _Bottone(
                icona: Icons.open_in_new,
                etichetta: 'Apri',
                onTap: () => launchUrl(Uri.parse(_link),
                    mode: LaunchMode.externalApplication),
              ),
            ],
          ),
          const SizedBox(height: 28),

          const _Titolo('La pagina della prenotazione'),
          const SizedBox(height: 6),
          const Text(
            'Dove il cliente ritrova la sua prenotazione e può scrivervi. Va '
            'già nelle email di conferma: serve solo se qualcuno l\'ha persa '
            'e ve la chiede.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          _Riquadro(testo: _linkStato),
          const SizedBox(height: 28),

          const _Titolo('Il modulo dentro un altro sito'),
          const SizedBox(height: 6),
          const Text(
            'Questo pezzo di codice mostra il modulo dentro una pagina, senza '
            'mandare il cliente altrove. Va dato a chi cura il sito: si '
            'incolla dove deve comparire.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          const _Riquadro(testo: _codice, monospazio: true),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }
}

class _Titolo extends StatelessWidget {
  final String testo;
  const _Titolo(this.testo);
  @override
  Widget build(BuildContext context) => Text(testo,
      style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold));
}

/// Testo da copiare, col suo pulsante.
class _Riquadro extends StatefulWidget {
  final String testo;
  final bool monospazio;
  final bool grande;
  final List<Widget> azioni;

  const _Riquadro({
    required this.testo,
    this.monospazio = false,
    this.grande = false,
    this.azioni = const [],
  });

  @override
  State<_Riquadro> createState() => _RiquadroState();
}

class _RiquadroState extends State<_Riquadro> {
  bool _copiato = false;

  Future<void> _copia() async {
    await Clipboard.setData(ClipboardData(text: widget.testo));
    if (!mounted) return;
    // La conferma sta sul pulsante e non in un messaggio a fondo schermo:
    // così si vede senza staccare gli occhi da quello che si è appena toccato.
    setState(() => _copiato = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copiato = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelectableText(
          widget.testo,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: widget.grande ? 17 : 14,
            fontWeight: widget.grande ? FontWeight.bold : FontWeight.normal,
            fontFamily: widget.monospazio ? 'monospace' : null,
            height: widget.monospazio ? 1.5 : null,
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _Bottone(
            icona: _copiato ? Icons.check : Icons.copy_all_outlined,
            etichetta: _copiato ? 'Copiato' : 'Copia',
            evidenza: _copiato,
            onTap: _copia,
          ),
          for (final a in widget.azioni) ...[const SizedBox(width: 8), a],
        ]),
      ]),
    );
  }
}

class _Bottone extends StatelessWidget {
  final IconData icona;
  final String etichetta;
  final VoidCallback onTap;
  final bool evidenza;

  const _Bottone({
    required this.icona,
    required this.etichetta,
    required this.onTap,
    this.evidenza = false,
  });

  @override
  Widget build(BuildContext context) {
    final tinta = evidenza ? AppColors.badgeGreen : AppColors.accent;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icona, size: 16, color: tinta),
      label: Text(etichetta, style: TextStyle(color: tinta)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: tinta.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
