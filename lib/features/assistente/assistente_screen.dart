import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/widgets/azioni_barra.dart';
import 'package:restaurant_booking/shared/widgets/contenuto_centrato.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
// L'esecuzione riusa le stesse funzioni dei pulsanti dell'app: la mail di
// conferma e quella di rifiuto devono comportarsi identiche, non "quasi".
import 'package:restaurant_booking/features/bookings/bookings_screen.dart'
    show sendBookingAcceptedEmail, RejectionScreen;

enum StatoProposta { attesa, eseguita, scartata }

/// Un'operazione preparata dall'assistente, ferma finché non la si conferma.
class _Proposta {
  final Map<String, dynamic> dati;
  StatoProposta stato = StatoProposta.attesa;
  String? esito;
  bool inCorso = false;
  _Proposta(this.dati);

  String get tipo => (dati['tipo'] ?? '').toString();
  String get titolo => (dati['titolo'] ?? 'Operazione').toString();
  String get descrizione => (dati['descrizione'] ?? '').toString();
  String? get avviso => dati['avviso']?.toString();
  Map<String, dynamic> get prenotazione =>
      Map<String, dynamic>.from(dati['prenotazione'] as Map? ?? const {});
  Map<String, dynamic> get valori =>
      Map<String, dynamic>.from(dati['valori'] as Map? ?? const {});
}

class _Messaggio {
  final String testo;
  final bool mio;
  final bool errore;
  final List<_Proposta> proposte;

  /// Cosa ha consultato per rispondere, con i valori che ha usato.
  /// Serve a smascherare le risposte plausibili ma sbagliate: se dice
  /// "una sola a settembre" ma ha guardato un giorno solo, qui si vede.
  final String? fonte;

  const _Messaggio(this.testo, {
    this.mio = false,
    this.errore = false,
    this.fonte,
    this.proposte = const [],
  });
}

/// "conteggi_periodo {da: 2026-09-01, a: 2026-09-30}" -> testo leggibile.
String? _descriviFonti(dynamic strumenti, String? modello) {
  final pezzi = <String>[];
  if (strumenti is! List || strumenti.isEmpty) {
    // Ha risposto senza consultare nulla: vale la pena saperlo.
    return modello == null ? null : 'niente — risposta a braccio · $modello';
  }
  for (final s in strumenti) {
    if (s is! Map) {
      pezzi.add(s.toString().replaceAll('_', ' '));
      continue;
    }
    final nome = (s['nome'] ?? '').toString().replaceAll('_', ' ');
    final arg = s['argomenti'];
    final valori = arg is Map && arg.isNotEmpty
        ? arg.entries.map((e) => '${e.key} ${e.value}').join(', ')
        : '';
    pezzi.add(valori.isEmpty ? nome : '$nome ($valori)');
  }
  if (modello != null && modello.isNotEmpty) pezzi.add(modello);
  return pezzi.join(' · ');
}

/// L'assistente: domande a voce sulle prenotazioni, risposte coi dati veri.
///
/// La schermata non sa nulla del modello: manda la domanda alla funzione
/// `assistente`, che prende i dati dal database e li fa formulare a OpenAI.
/// La chiave resta sul server, qui non passa mai.
class AssistenteScreen extends StatefulWidget {
  const AssistenteScreen({super.key});

  @override
  State<AssistenteScreen> createState() => _AssistenteScreenState();
}

class _AssistenteScreenState extends State<AssistenteScreen> {
  final _testo = TextEditingController();
  final _scorrimento = ScrollController();
  final _messaggi = <_Messaggio>[];
  bool _inCorso = false;

  static const _esempi = [
    'Chi viene stasera?',
    'Quante persone abbiamo sabato?',
    'Il signor Ferrara ha prenotato?',
    'Com\'è andato questo mese?',
    'Accetta la prenotazione dei Ferrara di sabato',
    'Quali giorni siamo chiusi?',
  ];

  @override
  void dispose() {
    _testo.dispose();
    _scorrimento.dispose();
    super.dispose();
  }

  Future<void> _chiedi(String domanda) async {
    final d = domanda.trim();
    if (d.isEmpty || _inCorso) return;
    setState(() {
      _messaggi.add(_Messaggio(d, mio: true));
      _inCorso = true;
      _testo.clear();
    });
    _giuInFondo();

    try {
      // Le ultime battute servono a capire i riferimenti: "e domani?"
      final cronologia = _messaggi
          .where((m) => !m.errore)
          .map((m) => {'ruolo': m.mio ? 'utente' : 'assistente', 'testo': m.testo})
          .toList();
      cronologia.removeLast(); // la domanda appena fatta viaggia a parte

      final res = await Supabase.instance.client.functions.invoke(
        'assistente',
        body: {'domanda': d, 'cronologia': cronologia},
      );
      final dati = res.data;
      if (!mounted) return;
      if (dati is Map && dati['error'] != null) {
        setState(() => _messaggi.add(_Messaggio(dati['error'].toString(), errore: true)));
      } else {
        final testo = (dati is Map ? dati['risposta']?.toString() : null) ?? '';
        setState(() => _messaggi.add(_Messaggio(
            testo.isEmpty ? 'Non ho una risposta per questa domanda.' : testo,
            fonte: _descriviFonti(
              dati is Map ? dati['strumenti'] : null,
              dati is Map ? dati['modello']?.toString() : null,
            ),
            proposte: [
              for (final p in (dati is Map ? dati['proposte'] as List? : null) ?? const [])
                if (p is Map) _Proposta(Map<String, dynamic>.from(p)),
            ])));
      }
    } on FunctionException catch (e) {
      // Con uno stato diverso da 200 il client solleva invece di restituire:
      // il motivo vero sta in `details`, non nel messaggio dell'eccezione.
      if (!mounted) return;
      final d = e.details;
      final motivo = d is Map && d['error'] != null ? d['error'].toString() : d?.toString();
      setState(() => _messaggi.add(_Messaggio(
          motivo?.isNotEmpty == true ? motivo! : 'Errore ${e.status}', errore: true)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messaggi.add(_Messaggio(
          'Non sono riuscito a rispondere: $e', errore: true)));
    } finally {
      if (mounted) setState(() => _inCorso = false);
      _giuInFondo();
    }
  }

  void _giuInFondo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scorrimento.hasClients) {
        _scorrimento.animateTo(
          _scorrimento.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Assistente',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        actions: [
          if (_messaggi.isNotEmpty)
            IconButton(
              tooltip: 'Ricomincia',
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: () => setState(_messaggi.clear),
            ),
          ...azioniBarra(context),
        ],
      ),
      body: ContenutoCentrato(
        larghezzaMassima: 820,
        child: Column(children: [
          Expanded(
            child: _messaggi.isEmpty ? _benvenuto() : _conversazione(),
          ),
          _barraDomanda(),
        ]),
      ),
    );
  }

  Widget _benvenuto() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 44, color: AppColors.gold),
          const SizedBox(height: 16),
          const Text('Chiedi quello che ti serve',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Risponde leggendo le prenotazioni vere: non inventa numeri né nomi. '
            'Può anche preparare operazioni — accettare, assegnare un tavolo, '
            'annullare — ma non le esegue: le confermi tu, una per una.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          for (final e in _esempi)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => _chiedi(e),
                child: Text(e, style: const TextStyle(fontSize: 14)),
              ),
            ),
        ],
      );

  Widget _conversazione() => ListView.builder(
        controller: _scorrimento,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: _messaggi.length + (_inCorso ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _messaggi.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
                SizedBox(width: 10),
                Text('Sto guardando le prenotazioni…',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            );
          }
          final m = _messaggi[i];
          final bolla = Align(
            alignment: m.mio ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 620),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: m.errore
                    ? AppColors.accentLight
                    : m.mio
                        ? AppColors.textPrimary
                        : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: m.errore ? AppColors.accent : AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    m.testo,
                    style: TextStyle(
                      color: m.errore
                          ? AppColors.accent
                          : m.mio
                              ? Colors.white
                              : AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  if (m.fonte != null) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.divider),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.travel_explore_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text('Ha guardato: ${m.fonte}',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.35)),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          );

          if (m.proposte.isEmpty) return bolla;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [bolla, for (final p in m.proposte) _riquadroProposta(p)],
          );
        },
      );

  /// Il riquadro che ferma l'operazione finché una persona non la guarda.
  Widget _riquadroProposta(_Proposta p) {
    final fatta = p.stato == StatoProposta.eseguita;
    final scartata = p.stato == StatoProposta.scartata;
    final chiusa = fatta || scartata;
    final allarme = (p.avviso ?? '').startsWith('Attenzione');

    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: chiusa
              ? AppColors.divider
              : allarme
                  ? AppColors.accent
                  : AppColors.gold,
          width: chiusa ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(
              fatta
                  ? Icons.check_circle
                  : scartata
                      ? Icons.cancel_outlined
                      : Icons.pending_actions_outlined,
              size: 18,
              color: fatta
                  ? AppColors.badgeGreen
                  : scartata
                      ? AppColors.textSecondary
                      : AppColors.goldDark,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(p.titolo,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(p.descrizione,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14, height: 1.45)),
          if (p.avviso != null && !chiusa) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(allarme ? Icons.warning_amber_rounded : Icons.mail_outline,
                  size: 14,
                  color: allarme ? AppColors.accent : AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(p.avviso!,
                    style: TextStyle(
                        color: allarme ? AppColors.accent : AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4)),
              ),
            ]),
          ],
          if (p.esito != null) ...[
            const SizedBox(height: 8),
            Text(p.esito!,
                style: TextStyle(
                    color: fatta ? AppColors.badgeGreen : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
          if (!chiusa) ...[
            const SizedBox(height: 12),
            Row(children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.badgeGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
                onPressed: p.inCorso ? null : () => _conferma(p),
                icon: p.inCorso
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check, size: 16),
                label: const Text('Conferma'),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                onPressed: p.inCorso
                    ? null
                    : () => setState(() {
                          p.stato = StatoProposta.scartata;
                          p.esito = 'Non eseguita.';
                        }),
                child: const Text('Lascia stare'),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Future<void> _conferma(_Proposta p) async {
    if (p.inCorso || p.stato != StatoProposta.attesa) return;
    final b = p.prenotazione;
    final id = b['id'];
    if (id == null) {
      setState(() {
        p.stato = StatoProposta.scartata;
        p.esito = 'Prenotazione non identificata: non tocco niente.';
      });
      return;
    }

    setState(() => p.inCorso = true);
    final db = Supabase.instance.client;
    try {
      switch (p.tipo) {
        case 'accetta':
          await db.from('bookings').update({'status': 'approved'}).eq('id', id);
          // Stessa funzione del pulsante: incrementa le visite e manda la mail.
          await sendBookingAcceptedEmail(b);
          p.esito = 'Accettata, mail di conferma inviata.';
          break;

        case 'tavolo':
          await db
              .from('bookings')
              .update({'table_id': p.valori['table_id']}).eq('id', id);
          p.esito = 'Assegnata al tavolo ${p.valori['tavolo']}.';
          break;

        case 'modifica':
          await db.from('bookings').update(p.valori).eq('id', id);
          p.esito = 'Prenotazione aggiornata.';
          break;

        case 'annulla':
          // Non annullo qui: apro la schermata di rifiuto dell'app, dove il
          // messaggio al cliente si rilegge e si corregge prima di partire.
          if (!mounted) return;
          var confermato = false;
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RejectionScreen(
              booking: b,
              onRejected: () => confermato = true,
            ),
          ));
          if (!confermato) {
            if (mounted) setState(() => p.inCorso = false);
            return; // torna in attesa: si può riprovare
          }
          p.esito = 'Annullata, messaggio inviato al cliente.';
          break;

        default:
          p.esito = 'Operazione sconosciuta: non tocco niente.';
          if (mounted) {
            setState(() {
              p.stato = StatoProposta.scartata;
              p.inCorso = false;
            });
          }
          return;
      }
      if (mounted) {
        setState(() {
          p.stato = StatoProposta.eseguita;
          p.inCorso = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          p.inCorso = false;
          p.esito = 'Non riuscita: $e';
        });
      }
    }
  }

  Widget _barraDomanda() => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        color: AppColors.background,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _testo,
              enabled: !_inCorso,
              onSubmitted: _chiedi,
              textInputAction: TextInputAction.send,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Scrivi una domanda…',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
            onPressed: _inCorso ? null : () => _chiedi(_testo.text),
            child: _inCorso
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
          ),
        ]),
      );
}
