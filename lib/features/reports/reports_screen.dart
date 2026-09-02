import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/widgets/azioni_barra.dart';
import 'package:restaurant_booking/shared/widgets/contenuto_centrato.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/features/bookings/scelte_modulo.dart';
import 'package:restaurant_booking/shared/widgets/pulsante_barra.dart';

const _idRistorante = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

enum Periodo { trentaGiorni, mese, anno, sempre }

/// I rapporti: cosa e' successo in sala, letto dalle prenotazioni.
///
/// Tutte le prenotazioni vengono lette una volta sola e i conti si fanno qui:
/// sono poche centinaia, e una decina di interrogazioni separate — una per
/// grafico — costerebbe piu' del calcolo.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _tutte = [];
  bool _inCaricamento = true;
  String? _errore;
  Periodo _periodo = Periodo.trentaGiorni;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _inCaricamento = true;
      _errore = null;
    });
    try {
      final righe = await Supabase.instance.client
          .from('bookings')
          .select('id, date, time_start, party_size, status, source, created_at, '
              'internal_notes, guest_id, tables!bookings_table_id_fkey(areas(name))')
          .eq('restaurant_id', _idRistorante)
          .order('date');
      if (!mounted) return;
      setState(() {
        _tutte = [for (final r in righe) Map<String, dynamic>.from(r as Map)];
        _inCaricamento = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.toString();
        _inCaricamento = false;
      });
    }
  }

  // ── Selezione del periodo ─────────────────────────────────────────────────

  (DateTime, DateTime) get _estremi {
    final ora = DateTime.now();
    return switch (_periodo) {
      Periodo.trentaGiorni => (ora.subtract(const Duration(days: 30)), ora),
      Periodo.mese => (DateTime(ora.year, ora.month, 1), DateTime(ora.year, ora.month + 1, 0)),
      Periodo.anno => (DateTime(ora.year, 1, 1), DateTime(ora.year, 12, 31)),
      Periodo.sempre => (DateTime(2000), DateTime(2100)),
    };
  }

  String get _etichettaPeriodo => switch (_periodo) {
        Periodo.trentaGiorni => 'Ultimi 30 giorni',
        Periodo.mese => 'Questo mese',
        Periodo.anno => 'Quest\'anno',
        Periodo.sempre => 'Dall\'inizio',
      };

  List<Map<String, dynamic>> get _nelPeriodo {
    final (da, a) = _estremi;
    final dal = DateTime(da.year, da.month, da.day);
    final al = DateTime(a.year, a.month, a.day);
    return _tutte.where((b) {
      final d = DateTime.tryParse((b['date'] ?? '').toString());
      if (d == null) return false;
      final g = DateTime(d.year, d.month, d.day);
      return !g.isBefore(dal) && !g.isAfter(al);
    }).toList();
  }

  // ── Conti ─────────────────────────────────────────────────────────────────

  bool _valida(Map<String, dynamic> b) =>
      b['status'] == 'approved' || b['status'] == 'pending' || b['status'] == 'seated';

  int _coperti(Iterable<Map<String, dynamic>> righe) =>
      righe.fold(0, (s, b) => s + ((b['party_size'] as int?) ?? 0));

  String _area(Map<String, dynamic> b) {
    // Prima l'area del tavolo assegnato, poi quella chiesta nel modulo.
    final t = b['tables'] as Map<String, dynamic>?;
    final daTavolo = (t?['areas'] as Map<String, dynamic>?)?['name']?.toString().trim();
    if (daTavolo != null && daTavolo.isNotEmpty) return daTavolo.toUpperCase();
    final scelta = ScelteModulo.da(b['internal_notes']).area;
    return scelta.isEmpty ? 'NON INDICATA' : scelta.toUpperCase();
  }

  String _turno(Map<String, dynamic> b) {
    final t = ScelteModulo.da(b['internal_notes']).turno.toUpperCase();
    if (t.contains('APERITIF') || t.contains('APERITIVO')) return 'Aperitivo';
    if (t.contains('1°') || t.contains('1 TURNO')) return '1° turno';
    if (t.contains('2°') || t.contains('2 TURNO')) return '2° turno';
    // Chi non l'ha scelto — le prenotazioni prese al telefono — si colloca
    // sull'orario, altrimenti sparirebbe dal conto.
    final ora = (b['time_start'] ?? '').toString();
    if (ora.startsWith('18') || ora.startsWith('19')) return 'Aperitivo';
    if (ora.startsWith('20') || ora.startsWith('21')) return '1° turno';
    if (ora.startsWith('22') || ora.startsWith('23')) return '2° turno';
    return 'Non indicato';
  }

  Map<String, int> _perChiave(
      Iterable<Map<String, dynamic>> righe, String Function(Map<String, dynamic>) chiave) {
    final m = <String, int>{};
    for (final b in righe) {
      m[chiave(b)] = (m[chiave(b)] ?? 0) + ((b['party_size'] as int?) ?? 0);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: const PulsanteBarra(),
        title: const Text('Rapporti',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        actions: azioniBarra(context),
      ),
      body: _inCaricamento
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _errore != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Dati non caricati: $_errore',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : ContenutoCentrato(child: _contenuto()),
    );
  }

  Widget _contenuto() {
    final righe = _nelPeriodo;
    final valide = righe.where(_valida).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _carica,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _selettorePeriodo(),
          const SizedBox(height: 16),
          if (righe.isEmpty)
            const _Pannello(
              titolo: 'Nessuna prenotazione nel periodo',
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Cambia periodo, oppure aspetta: i rapporti si riempiono da soli '
                  'man mano che arrivano le prenotazioni.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
              ),
            )
          else ...[
            _riepilogo(righe, valide),
            const SizedBox(height: 12),
            _copertiPerGiorno(valide),
            const SizedBox(height: 12),
            _Pannello(
              titolo: 'Coperti per turno',
              sottotitolo: 'Chi non l\'ha scelto è collocato sull\'orario',
              child: _barre(_perChiave(valide, _turno),
                  ordine: const ['Aperitivo', '1° turno', '2° turno', 'Non indicato']),
            ),
            const SizedBox(height: 12),
            _Pannello(
              titolo: 'Coperti per area',
              sottotitolo: 'Area del tavolo assegnato, o quella richiesta nel modulo',
              child: _barre(_perChiave(valide, _area)),
            ),
            const SizedBox(height: 12),
            _Pannello(
              titolo: 'Coperti per giorno della settimana',
              child: _barre(_perGiornoSettimana(valide),
                  ordine: const ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì',
                                 'Venerdì', 'Sabato', 'Domenica']),
            ),
            const SizedBox(height: 12),
            _esiti(righe),
            const SizedBox(height: 12),
            _clienti(righe),
            const SizedBox(height: 12),
            _anticipo(righe),
          ],
        ],
      ),
    );
  }

  Widget _selettorePeriodo() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in Periodo.values)
            ChoiceChip(
              label: Text(switch (p) {
                Periodo.trentaGiorni => '30 giorni',
                Periodo.mese => 'Questo mese',
                Periodo.anno => 'Quest\'anno',
                Periodo.sempre => 'Dall\'inizio',
              }),
              selected: _periodo == p,
              onSelected: (_) => setState(() => _periodo = p),
              selectedColor: AppColors.accentLight,
              labelStyle: TextStyle(
                color: _periodo == p ? AppColors.accent : AppColors.textSecondary,
                fontWeight: _periodo == p ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              backgroundColor: AppColors.surface,
              side: BorderSide(
                  color: _periodo == p ? AppColors.accent : AppColors.divider),
            ),
        ],
      );

  Widget _riepilogo(List<Map<String, dynamic>> righe, List<Map<String, dynamic>> valide) {
    final coperti = _coperti(valide);
    final media = valide.isEmpty ? 0.0 : coperti / valide.length;
    final dalSito = righe.where((b) => b['source'] == 'web').length;
    return _Pannello(
      titolo: _etichettaPeriodo,
      child: Wrap(spacing: 24, runSpacing: 16, children: [
        _Numero(valore: '${valide.length}', etichetta: 'Prenotazioni'),
        _Numero(valore: '$coperti', etichetta: 'Coperti'),
        _Numero(valore: media.toStringAsFixed(1), etichetta: 'Persone a tavolo'),
        _Numero(
            valore: righe.isEmpty ? '—' : '${(dalSito * 100 / righe.length).round()}%',
            etichetta: 'Dal sito'),
      ]),
    );
  }

  Widget _copertiPerGiorno(List<Map<String, dynamic>> valide) {
    final perGiorno = <String, int>{};
    for (final b in valide) {
      final d = (b['date'] ?? '').toString().substring(0, 10);
      perGiorno[d] = (perGiorno[d] ?? 0) + ((b['party_size'] as int?) ?? 0);
    }
    final giorni = perGiorno.keys.toList()..sort();
    final massimo = perGiorno.values.fold(0, (a, b) => a > b ? a : b);

    return _Pannello(
      titolo: 'Coperti per giorno',
      sottotitolo: giorni.length > 20 ? 'Scorri per vedere tutto il periodo' : null,
      child: SizedBox(
        height: 170,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final g in giorni)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${perGiorno[g]}',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: 26,
                    height: massimo == 0 ? 2 : (perGiorno[g]! / massimo) * 110,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 30,
                    child: Text(
                      DateFormat('d/M').format(DateTime.parse(g)),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Map<String, int> _perGiornoSettimana(List<Map<String, dynamic>> valide) {
    const nomi = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
    final m = <String, int>{};
    for (final b in valide) {
      final d = DateTime.tryParse((b['date'] ?? '').toString());
      if (d == null) continue;
      final n = nomi[d.weekday - 1];
      m[n] = (m[n] ?? 0) + ((b['party_size'] as int?) ?? 0);
    }
    return m;
  }

  Widget _esiti(List<Map<String, dynamic>> righe) {
    final conteggi = <String, int>{};
    for (final b in righe) {
      final s = switch (b['status']) {
        'approved' => 'Accettate',
        'pending' => 'In attesa',
        'seated' => 'Arrivate',
        'completed' => 'Concluse',
        'canceled' => 'Annullate dal cliente',
        'rejected' => 'Rifiutate',
        'canceled_by_venue' => 'Cancellate dal locale',
        'no_show' => 'Non presentati',
        _ => 'Altro',
      };
      conteggi[s] = (conteggi[s] ?? 0) + 1;
    }
    final mancate = conteggi['Non presentati'] ?? 0;
    return _Pannello(
      titolo: 'Come sono andate a finire',
      sottotitolo: mancate == 0
          ? null
          : '$mancate ${mancate == 1 ? 'persona non si è presentata' : 'volte nessuno si è presentato'}',
      child: _barre(conteggi, unita: 'prenotazioni'),
    );
  }

  Widget _clienti(List<Map<String, dynamic>> righe) {
    // Prima volta o gia' visto: si guarda se quel cliente ha prenotazioni
    // precedenti in tutto l'archivio, non solo nel periodo scelto.
    final primaVolta = <String, DateTime>{};
    for (final b in _tutte) {
      final id = b['guest_id']?.toString();
      final d = DateTime.tryParse((b['date'] ?? '').toString());
      if (id == null || d == null) continue;
      final attuale = primaVolta[id];
      if (attuale == null || d.isBefore(attuale)) primaVolta[id] = d;
    }
    var nuovi = 0, ritorno = 0, senzaScheda = 0;
    for (final b in righe) {
      final id = b['guest_id']?.toString();
      final d = DateTime.tryParse((b['date'] ?? '').toString());
      if (id == null) {
        senzaScheda++;
        continue;
      }
      if (d != null && primaVolta[id] != null && d.isAfter(primaVolta[id]!)) {
        ritorno++;
      } else {
        nuovi++;
      }
    }
    return _Pannello(
      titolo: 'Clienti nuovi e di ritorno',
      sottotitolo: senzaScheda == 0
          ? null
          : '$senzaScheda senza scheda cliente, non classificabili',
      child: _barre({'Prima volta': nuovi, 'Già stati qui': ritorno},
          unita: 'prenotazioni'),
    );
  }

  Widget _anticipo(List<Map<String, dynamic>> righe) {
    final fasce = <String, int>{
      'Stesso giorno': 0,
      'Da 1 a 3 giorni': 0,
      'Da 4 a 7 giorni': 0,
      'Oltre una settimana': 0,
    };
    var contate = 0;
    for (final b in righe) {
      final quando = DateTime.tryParse((b['created_at'] ?? '').toString());
      final per = DateTime.tryParse((b['date'] ?? '').toString());
      if (quando == null || per == null) continue;
      final giorni = DateTime(per.year, per.month, per.day)
          .difference(DateTime(quando.year, quando.month, quando.day))
          .inDays;
      contate++;
      if (giorni <= 0) {
        fasce['Stesso giorno'] = fasce['Stesso giorno']! + 1;
      } else if (giorni <= 3) {
        fasce['Da 1 a 3 giorni'] = fasce['Da 1 a 3 giorni']! + 1;
      } else if (giorni <= 7) {
        fasce['Da 4 a 7 giorni'] = fasce['Da 4 a 7 giorni']! + 1;
      } else {
        fasce['Oltre una settimana'] = fasce['Oltre una settimana']! + 1;
      }
    }
    return _Pannello(
      titolo: 'Con quanto anticipo prenotano',
      sottotitolo: contate == 0 ? null : 'Su $contate prenotazioni',
      child: _barre(fasce,
          unita: 'prenotazioni',
          ordine: const ['Stesso giorno', 'Da 1 a 3 giorni', 'Da 4 a 7 giorni',
                         'Oltre una settimana']),
    );
  }

  /// Barre orizzontali: si leggono meglio delle torte quando le voci hanno
  /// nomi lunghi, e si confrontano a colpo d'occhio.
  Widget _barre(Map<String, int> dati, {String unita = 'coperti', List<String>? ordine}) {
    final voci = (ordine ?? (dati.keys.toList()..sort((a, b) => dati[b]!.compareTo(dati[a]!))))
        .where((k) => (dati[k] ?? 0) > 0)
        .toList();
    if (voci.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Nessun dato.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
    }
    final massimo = voci.map((k) => dati[k]!).fold(0, (a, b) => a > b ? a : b);
    final totale = voci.fold(0, (s, k) => s + dati[k]!);

    return Column(children: [
      for (final k in voci) ...[
        Row(children: [
          SizedBox(
            width: 150,
            child: Text(k,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, v) {
              return Container(
                height: 22,
                alignment: Alignment.centerLeft,
                child: Container(
                  width: massimo == 0 ? 0 : (dati[k]! / massimo) * v.maxWidth,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(
              '${dati[k]}  ·  ${totale == 0 ? 0 : (dati[k]! * 100 / totale).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 2),
      Align(
        alignment: Alignment.centerRight,
        child: Text('Totale $totale $unita',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ),
    ]);
  }
}

// ── Pezzi comuni ────────────────────────────────────────────────────────────

class _Pannello extends StatelessWidget {
  final String titolo;
  final String? sottotitolo;
  final Widget child;
  const _Pannello({required this.titolo, this.sottotitolo, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titolo,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          if (sottotitolo != null) ...[
            const SizedBox(height: 2),
            Text(sottotitolo!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          child,
        ]),
      );
}

class _Numero extends StatelessWidget {
  final String valore, etichetta;
  const _Numero({required this.valore, required this.etichetta});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valore,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 34, fontWeight: FontWeight.w300)),
          Text(etichetta,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      );
}
