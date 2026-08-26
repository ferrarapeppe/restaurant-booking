import 'package:flutter/material.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/azioni_barra.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';
import 'package:restaurant_booking/features/bookings/stato_giornata.dart';
import 'package:restaurant_booking/features/bookings/scelte_modulo.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final String? initialFilter;

  /// 'settimana', 'mese' o 'anno': mostra tutte le prenotazioni del periodo
  /// invece di una giornata sola. Arriva dai riquadri del pannello.
  final String? initialPeriodo;

  const BookingsScreen({
    super.key,
    this.initialDate,
    this.initialFilter,
    this.initialPeriodo,
  });
  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  static const _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  final _supabase = Supabase.instance.client;
  String _statusFilter = 'attivo';
  String? _sourceFilter;
  List<Map<String, dynamic>> _bookingsWithDetails = [];
  bool _loading = false;

  final _statusOptions = [
    {'value': 'attivo', 'label': 'Attivo', 'icon': Icons.play_arrow},
    {'value': 'tutti', 'label': 'Qualsiasi stato', 'icon': Icons.filter_list},
    {'value': 'approved', 'label': 'Accettato', 'icon': Icons.thumb_up_outlined},
    {'value': 'pending', 'label': 'In attesa di conferma', 'icon': Icons.help_outline},
    {'value': 'seated', 'label': 'Accomodato', 'icon': Icons.chair_outlined},
    {'value': 'canceled', 'label': 'Annullato', 'icon': Icons.close},
    {'value': 'no_show', 'label': 'No-show', 'icon': Icons.block_outlined},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialDate != null) {
        ref.read(selectedDateProvider.notifier).state = widget.initialDate!;
      }
      if (widget.initialFilter == 'da_assegnare') {
        _statusFilter = 'pending';
        _sourceFilter = 'web';
      }
      _periodo = widget.initialPeriodo;
      _loadBookings();
      _caricaStatoGiornata();
    });
  }

  /// Turno mostrato: 'tutti', 'aperitivo', 'primo', 'secondo'.
  ///
  /// Il riquadro "Tutto il giorno" era un rettangolo con disegnata una
  /// freccina e nessuna reazione al tocco: sembrava un comando e non lo era.
  String _turnoFiltro = 'tutti';

  static const _turniDisponibili = [
    ('tutti', 'Tutto il giorno', Icons.schedule_outlined),
    ('aperitivo', 'Aperitivo', Icons.wine_bar_outlined),
    ('primo', '1° turno', Icons.restaurant_outlined),
    ('secondo', '2° turno', Icons.nightlife_outlined),
  ];

  String get _etichettaTurnoFiltro =>
      _turniDisponibili.firstWhere((t) => t.$1 == _turnoFiltro).$2;

  /// A quale turno appartiene una prenotazione.
  ///
  /// Quelle prese al telefono non hanno un turno scelto — lo sceglie il cliente
  /// nel modulo — quindi si collocano sull'orario, altrimenti sparirebbero da
  /// ogni filtro diverso da "tutto il giorno".
  String _turnoDi(Map<String, dynamic> b) {
    final t = ScelteModulo.da(b['internal_notes']).turno.toUpperCase();
    if (t.contains('APERITIF') || t.contains('APERITIVO')) return 'aperitivo';
    if (t.contains('1°') || t.contains('1 TURNO')) return 'primo';
    if (t.contains('2°') || t.contains('2 TURNO')) return 'secondo';
    final ora = (b['time_start'] ?? '').toString();
    if (ora.startsWith('18') || ora.startsWith('19')) return 'aperitivo';
    if (ora.startsWith('20') || ora.startsWith('21')) return 'primo';
    if (ora.startsWith('22') || ora.startsWith('23')) return 'secondo';
    return 'altro';
  }

  /// Stati che contano come prenotazione viva.
  static const _statiAttivi = {'approved', 'pending', 'seated', 'completed'};

  /// Le righe del periodo dopo il solo filtro sul turno: la base su cui si
  /// contano gli stati, perche' i numeri devono seguire il turno scelto.
  List<Map<String, dynamic>> get _delTurno => _turnoFiltro == 'tutti'
      ? _bookingsWithDetails
      : _bookingsWithDetails.where((b) => _turnoDi(b) == _turnoFiltro).toList();

  bool _passaStato(Map<String, dynamic> b) {
    final s = (b['status'] ?? '').toString();
    if (_statusFilter == 'tutti') return true;
    if (_statusFilter == 'attivo') return _statiAttivi.contains(s);
    return s == _statusFilter;
  }

  /// Le prenotazioni effettivamente mostrate, dopo turno e stato.
  List<Map<String, dynamic>> get _visibili =>
      _delTurno.where(_passaStato).toList();

  /// Quante righe per ogni stato, per le pastiglie sopra la tabella.
  Map<String, int> get _conteggiStato {
    final m = <String, int>{'attivo': 0, 'tutti': _delTurno.length};
    for (final b in _delTurno) {
      final s = (b['status'] ?? '').toString();
      m[s] = (m[s] ?? 0) + 1;
      if (_statiAttivi.contains(s)) m['attivo'] = (m['attivo'] ?? 0) + 1;
    }
    return m;
  }

  void _mostraFiltroTurno(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final t in _turniDisponibili)
              ListTile(
                leading: Icon(t.$3,
                    color: _turnoFiltro == t.$1 ? AppColors.accent : AppColors.textSecondary),
                title: Text(t.$2,
                    style: TextStyle(
                      color: _turnoFiltro == t.$1 ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: _turnoFiltro == t.$1 ? FontWeight.bold : FontWeight.normal,
                    )),
                trailing: Text(
                  '${t.$1 == 'tutti' ? _bookingsWithDetails.length : _bookingsWithDetails.where((b) => _turnoDi(b) == t.$1).length}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                onTap: () {
                  setState(() => _turnoFiltro = t.$1);
                  Navigator.pop(context);
                },
              ),
          ]),
      ),
    );
  }

  /// Periodo mostrato al posto della singola giornata, se impostato.
  String? _periodo;

  /// Estremi del periodo scelto dal pannello di controllo.
  (DateTime, DateTime)? get _estremiPeriodo {
    final ora = DateTime.now();
    return switch (_periodo) {
      'settimana' => (ora, ora.add(const Duration(days: 7))),
      'mese' => (DateTime(ora.year, ora.month, 1), DateTime(ora.year, ora.month + 1, 0)),
      'anno' => (DateTime(ora.year, 1, 1), DateTime(ora.year, 12, 31)),
      _ => null,
    };
  }

  String get _etichettaPeriodo => switch (_periodo) {
        'settimana' => 'Prossimi 7 giorni',
        'mese' => 'Questo mese',
        'anno' => 'Tutto il ${DateTime.now().year}',
        'arrivate' => 'Arrivate oggi',
        'arrivate7' => 'Arrivate negli ultimi 7 giorni',
        _ => '',
      };

  /// L'elenco guarda l'ordine di arrivo invece della data di servizio.
  ///
  /// Sono due assi diversi: l'app e' organizzata su quando il cliente viene,
  /// ma il lavoro di approvazione segue quando la richiesta e' entrata. Senza
  /// questo, una prenotazione approvata sprofonda nella giornata a cui
  /// appartiene e per ritrovarla bisogna ricordarsi per quando era.
  bool get _perArrivo => _periodo == 'arrivate' || _periodo == 'arrivate7';

  DateTime get _daQuandoArrivate {
    final ora = DateTime.now();
    final oggi = DateTime(ora.year, ora.month, ora.day);
    return _periodo == 'arrivate7' ? oggi.subtract(const Duration(days: 6)) : oggi;
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    try {
      final date = ref.read(selectedDateProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      debugPrint('BOOKINGS LOAD date=$dateStr status=$_statusFilter periodo=$_periodo');
      var query = _supabase
          .from('bookings')
          .select('*, guests(first_name, surname, name, phone, email, tags), tables(name, capacity, area_id, areas(name))')
          .eq('restaurant_id', _restaurantId);
      final estremi = _estremiPeriodo;
      if (_sourceFilter == 'web') {
        query = query.eq('source', 'web').eq('status', 'pending');
      } else if (_perArrivo) {
        query = query.gte('created_at', _daQuandoArrivate.toIso8601String());
      } else if (estremi != null) {
        query = query
            .gte('date', DateFormat('yyyy-MM-dd').format(estremi.$1))
            .lte('date', DateFormat('yyyy-MM-dd').format(estremi.$2));
      } else {
        query = query.eq('date', dateStr);
      }
      // Lo stato non lo filtra piu' il database ma `_visibili`: servono tutte
      // le righe per poter dire "Annullate (2)" accanto ad "Attive (2)".
      // Senza il conteggio, una prenotazione disdetta spariva e basta.

      // Guardando gli arrivi conta l'ordine in cui sono entrate, dalla piu'
      // recente. Su piu' giorni di servizio, l'ora da sola non basta.
      final res = _perArrivo
          ? await query.order('created_at', ascending: false)
          : estremi != null
              ? await query.order('date').order('time_start')
              : await query.order('time_start');
      debugPrint('BOOKINGS RESULT count=${res.length}');
      setState(() {
        _bookingsWithDetails = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('BOOKINGS ERROR: $e\n$st');
      setState(() => _loading = false);
    }
  }

  // ── Prenotazioni online per la giornata mostrata ──────────────────────────
  // Blocca solo il modulo pubblico: lo staff continua a inserire prenotazioni
  // dall'app. Il blocco è una riga di orario speciale chiusa su quella data,
  // che il modulo già rispetta.
  StatoGiornata _statoGiornata = StatoGiornata.inCaricamento;
  String? _idBloccoGiornata;
  bool _cambioStatoInCorso = false;
  RegoleGiornate? _regole;

  Future<void> _caricaStatoGiornata() async {
    final data = ref.read(selectedDateProvider);
    try {
      final regole = await RegoleGiornate.carica();
      if (!mounted) return;
      setState(() {
        _regole = regole;
        _statoGiornata = regole.stato(data);
        _idBloccoGiornata = regole.idBlocco(data);
      });
    } catch (e) {
      debugPrint('stato giornata non caricato: $e');
      if (mounted) setState(() => _statoGiornata = StatoGiornata.sconosciuto);
    }
  }

  Future<void> _cambiaPrenotazioniOnline() async {
    if (_cambioStatoInCorso) return;
    if (_statoGiornata == StatoGiornata.chiusuraSettimanale) {
      _avviso('È il giorno di chiusura settimanale. Si cambia da Impostazioni → Orari di apertura.');
      return;
    }
    if (_statoGiornata == StatoGiornata.nonAncoraAperte) {
      _avviso(_regole?.motivoNonAperta(ref.read(selectedDateProvider)) ??
          'Il modulo non accetta prenotazioni per questa data.');
      return;
    }
    final data = ref.read(selectedDateProvider);
    setState(() => _cambioStatoInCorso = true);
    try {
      if (_statoGiornata == StatoGiornata.aperte) {
        final motivo = await RegoleGiornate.chiudi(data);
        _avviso(motivo == null
            ? 'Prenotazioni online chiuse per questa giornata.'
            : 'Non riuscito: $motivo.');
      } else if (_idBloccoGiornata != null) {
        final motivo = await RegoleGiornate.riapri(_idBloccoGiornata!);
        _avviso(motivo == null ? 'Prenotazioni online riaperte.' : 'Non riuscito: $motivo.');
      }
    } catch (e) {
      _avviso('Errore: $e');
    } finally {
      if (mounted) setState(() => _cambioStatoInCorso = false);
      await _caricaStatoGiornata();
    }
  }

  void _avviso(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(testo), backgroundColor: AppColors.accent, duration: const Duration(seconds: 3)),
    );
  }

  String _guestName(Map<String, dynamic> b) {
    final g = b['guests'];
    if (g == null) return 'Ospite';
    final fn = (g['first_name'] ?? '').toString().trim();
    final sn = (g['surname'] ?? '').toString().trim();
    if (fn.isNotEmpty || sn.isNotEmpty) return '$fn $sn'.trim().toUpperCase();
    return (g['name'] ?? 'Ospite').toString().toUpperCase();
  }


  void _changeDate(int delta) {
    // Spostarsi di un giorno significa voler tornare alla vista giornaliera.
    _periodo = null;
    final current = ref.read(selectedDateProvider);
    ref.read(selectedDateProvider.notifier).state = current.add(Duration(days: delta));
    _loadBookings();
    _caricaStatoGiornata();
  }

  void _tornaAllaGiornata() {
    setState(() => _periodo = null);
    _loadBookings();
    _caricaStatoGiornata();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime>(selectedDateProvider, (previous, next) {
      if (previous != next) { _loadBookings(); _caricaStatoGiornata(); }
    });

    final selectedDate = ref.watch(selectedDateProvider);
    final dayLabel = DateFormat('EEEE d MMM yyyy', 'it_IT').format(selectedDate);
    final capitalDay = dayLabel[0].toUpperCase() + dayLabel.substring(1);
    final total = _visibili.length;
    final totalGuests = _visibili.fold<int>(0, (s, b) => s + ((b['party_size'] as int?) ?? 0));
    final currentFilter = _statusOptions.firstWhere((s) => s['value'] == _statusFilter, orElse: () => _statusOptions[0]);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              onPressed: () => _changeDate(-1),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2027),
                  builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
                );
                if (picked != null) {
                  ref.read(selectedDateProvider.notifier).state = picked;
                  _loadBookings();
                }
              },
              child: Text(
                DateFormat('EEE d MMM', 'it_IT').format(selectedDate),
                style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              onPressed: () => _changeDate(1),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          ...azioniBarra(context, percorsoData: '/bookings'),
        ],
      ),
      // Un pannello bianco su fondo tortora, come le schede delle altre
      // schermate. Occupa quasi tutta la pagina invece di stringersi: la
      // tabella ha sette colonne e la larghezza le serve davvero.
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(_periodo != null ? _etichettaPeriodo : capitalDay,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              // Su un periodo il comando della giornata non ha senso: aprire o
              // chiudere "il mese" non vuol dire niente.
              if (_periodo == null)
                _MenuGiornata(
                  stato: _statoGiornata,
                  inCorso: _cambioStatoInCorso,
                  motivo: _statoGiornata == StatoGiornata.nonAncoraAperte
                      ? _regole?.motivoNonAperta(ref.read(selectedDateProvider))
                      : null,
                  onCambia: _cambiaPrenotazioniOnline,
                ),
            ]),
            if (_periodo != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: _tornaAllaGiornata,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_perArrivo ? Icons.inbox_outlined : Icons.date_range_outlined,
                        size: 13, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                        _perArrivo
                            ? 'Per ordine di arrivo — tocca per tornare alla giornata'
                            : 'Più giorni insieme — tocca per tornare alla giornata',
                        style: const TextStyle(
                            color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.close, size: 13, color: AppColors.accent),
                  ]),
                ),
              ),
              // Guardando gli arrivi si passa da oggi alla settimana senza
              // tornare al pannello: il lunedi' mattina si rivede il weekend.
              if (_perArrivo) ...[
                const SizedBox(height: 6),
                Row(children: [
                  for (final v in const [('arrivate', 'Oggi'), ('arrivate7', 'Ultimi 7 giorni')])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(v.$2, style: const TextStyle(fontSize: 12)),
                        selected: _periodo == v.$1,
                        onSelected: (_) {
                          setState(() => _periodo = v.$1);
                          _loadBookings();
                        },
                        selectedColor: AppColors.accentLight,
                        backgroundColor: AppColors.background,
                        side: BorderSide(
                            color: _periodo == v.$1 ? AppColors.accent : AppColors.divider),
                        labelStyle: TextStyle(
                          color: _periodo == v.$1 ? AppColors.accent : AppColors.textSecondary,
                          fontWeight:
                              _periodo == v.$1 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                ]),
              ],
            ],
            const SizedBox(height: 8),
            Row(children: [
              GestureDetector(
                onTap: () => _showStatusFilter(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(currentFilter['icon'] as IconData, color: AppColors.textPrimary, size: 16),
                    const SizedBox(width: 6),
                    Text('${currentFilter['label']}  $total \u2022 $totalGuests',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _mostraFiltroTurno(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _turnoFiltro == 'tutti' ? AppColors.divider : AppColors.accent),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.schedule_outlined, color: AppColors.textPrimary, size: 14),
                    const SizedBox(width: 6),
                    Text(_etichettaTurnoFiltro,
                        style: TextStyle(
                            color: _turnoFiltro == 'tutti'
                                ? AppColors.textPrimary
                                : AppColors.accent,
                            fontSize: 13,
                            fontWeight: _turnoFiltro == 'tutti'
                                ? FontWeight.normal
                                : FontWeight.bold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            // Quante ce ne sono per stato, e un tocco per vederle. Prima una
            // prenotazione annullata spariva senza lasciare traccia: il
            // calendario la contava, l'elenco no, e sembrava un guasto.
            Builder(builder: (_) {
              final c = _conteggiStato;
              final voci = <(String, String)>[
                ('attivo', 'Attive'),
                if ((c['pending'] ?? 0) > 0) ('pending', 'In attesa'),
                if ((c['canceled'] ?? 0) > 0) ('canceled', 'Annullate'),
                if ((c['no_show'] ?? 0) > 0) ('no_show', 'No-show'),
                if ((c['rejected'] ?? 0) > 0) ('rejected', 'Rifiutate'),
                if ((c['tutti'] ?? 0) != (c['attivo'] ?? 0)) ('tutti', 'Tutte'),
              ];
              return Wrap(spacing: 6, runSpacing: 6, children: [
                for (final v in voci)
                  _PastigliaStato(
                    etichetta: v.$2,
                    numero: c[v.$1] ?? 0,
                    scelta: _statusFilter == v.$1,
                    spenta: v.$1 == 'canceled' || v.$1 == 'no_show' || v.$1 == 'rejected',
                    // Le righe sono gia' in memoria: cambiare stato non
                    // richiede di tornare al database.
                    onTap: () => setState(() => _statusFilter = v.$1),
                  ),
              ]);
            }),
            const SizedBox(height: 6),
            Text('Mostrate $total \u2022 $totalGuests coperti',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),
        const Divider(height: 1, color: AppColors.divider),
        // Sette colonne non entrano su uno schermo stretto. Invece di
        // schiacciarle fino a renderle illeggibili, la tabella scorre in
        // orizzontale sotto una larghezza minima, intestazione compresa.
        Expanded(
          child: LayoutBuilder(builder: (context, vincoli) {
            const larghezzaMinima = 720.0;
            final larghezza = vincoli.maxWidth < larghezzaMinima
                ? larghezzaMinima
                : vincoli.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: larghezza,
                height: vincoli.maxHeight,
                child: Column(children: [
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                    child: const Row(children: [
                      _Intestazione(larghezza: 72, testo: 'Ora', sinistra: 8),
                      _Intestazione(larghezza: 78, testo: 'Persone', centrata: true),
                      _Intestazione(testo: 'Nome e Cognome', sinistra: 12),
                      _Intestazione(larghezza: 160, testo: 'Turno', sinistra: 4),
                      _Intestazione(larghezza: 86, testo: 'Tavolo', sinistra: 4),
                      _Intestazione(larghezza: 70, testo: 'Stato', centrata: true),
                    ]),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  Expanded(child: _corpoTabella(context)),
                ]),
              ),
            );
          }),
        ),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/bookings/new'),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _corpoTabella(BuildContext context) {
    return _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _visibili.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.event_busy, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        const Text('Nessuna prenotazione', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                      ]),
                    )
                  : ListView.separated(
                      itemCount: _visibili.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final b = _visibili[index];
                        return _BookingRow(
                          // Senza chiave, aggiornando l'elenco Flutter puo'
                          // riusare la riga sbagliata per una prenotazione
                          // diversa.
                          key: ValueKey(b['id']),
                          // Su piu' giorni la sola ora non basta a capire quando.
                          mostraData: _periodo != null,
                          mostraArrivo: _perArrivo,
                          booking: b,
                          guestName: _guestName(b),
                          onTap: () => _showBookingDetail(context, b),
                          onStatusChange: (newStatus) async {
                            final precedente = b['status'];
                            await _supabase.from('bookings')
                                .update({'status': newStatus}).eq('id', b['id']);
                            // L'email parte solo al passaggio ad "accettata"
                            if (newStatus == 'approved' && precedente != 'approved') {
                              sendBookingAcceptedEmail(b);
                            }
                            _loadBookings();
                          },
                          onReject: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => RejectionScreen(
                              booking: b,
                              onRejected: _loadBookings,
                            ),
                          )),
                        );
                      },
                    );
  }

  void _showStatusFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _statusOptions.map((opt) {
          final isSelected = _statusFilter == opt['value'];
          return ListTile(
            leading: Icon(opt['icon'] as IconData,
                color: isSelected ? AppColors.accent : AppColors.textSecondary),
            title: Text(opt['label'] as String,
                style: TextStyle(
                  color: isSelected ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
            trailing: isSelected ? const Icon(Icons.check, color: AppColors.accent) : null,
            onTap: () {
              setState(() => _statusFilter = opt['value'] as String);
              Navigator.pop(context);
              _loadBookings();
            },
          );
        }).toList(),
      ),
    );
  }

  void _showBookingDetail(BuildContext context, Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => BookingDetailSheet(
        booking: booking,
        onSaved: () { Navigator.pop(context); _loadBookings(); },
      ),
    );
  }

}

/// Pastiglia "Annullate (2)": conta e filtra insieme.
///
/// Gli stati spenti restano grigi anche da selezionati: un'annullata non deve
/// somigliare a una prenotazione viva nemmeno per un attimo.
class _PastigliaStato extends StatelessWidget {
  final String etichetta;
  final int numero;
  final bool scelta;
  final bool spenta;
  final VoidCallback onTap;

  const _PastigliaStato({
    required this.etichetta,
    required this.numero,
    required this.scelta,
    required this.spenta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tinta = spenta ? AppColors.textSecondary : AppColors.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: scelta
              ? (spenta ? AppColors.cardLight : AppColors.accentLight)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scelta ? tinta : AppColors.divider),
        ),
        child: Text(
          '$etichetta ($numero)',
          style: TextStyle(
            color: scelta ? tinta : AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: scelta ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Status menu items ─────────────────────────────────────────────────────────
const _kStatusChoices = [
  ('pending',   'Richiesta',          Icons.help_outline),
  ('approved',  'Accettato',          Icons.thumb_up_outlined),
  ('seated',    'Accomodato',         Icons.chair_outlined),
  ('left',      'Se ne è andato',     Icons.done_all),
  ('no_show',   'No-show',            Icons.block_outlined),
  ('canceled',  'Annullato',          Icons.close),
  ('rejected',  'Rifiuta (con email)',Icons.thumb_down_outlined),
];

Color _statusDotColor(String status) {
  switch (status) {
    case 'approved': return AppColors.statoAttesa;
    case 'seated':   return AppColors.statoConfermato;
    case 'left':     return Colors.grey;
    case 'canceled':
    case 'no_show':  return Colors.red;
    case 'pending':  return AppColors.statoAttesa;
    default:         return AppColors.textMuted;
  }
}

// ── Booking Row ───────────────────────────────────────────────────────────────
class _BookingRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String guestName;
  final VoidCallback onTap;
  final Future<void> Function(String)? onStatusChange;
  final VoidCallback? onReject;

  final bool mostraData;

  /// Quando guardiamo gli arrivi serve sapere quando la richiesta e' entrata,
  /// non solo per quando e'.
  final bool mostraArrivo;

  const _BookingRow({
    super.key,
    required this.booking,
    required this.guestName,
    required this.onTap,
    this.onStatusChange,
    this.onReject,
    this.mostraData = false,
    this.mostraArrivo = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeStart = (booking['time_start'] ?? '').toString().substring(0, 5);
    final timeEnd = booking['time_end'] != null
        ? booking['time_end'].toString().substring(0, 5)
        : '';
    final partySize = booking['party_size'] as int? ?? 0;
    final status = booking['status'] as String? ?? '';
    final table = booking['tables'] as Map<String, dynamic>?;
    final tableName = table?['name']?.toString() ?? '';
    final areaName =
        (table?['areas'] as Map<String, dynamic>?)?['name']?.toString() ?? '';
    final isPending = status == 'pending';
    final etichette = [
      for (final t in ((booking['guests'] as Map?)?['tags'] as List? ?? const []))
        t.toString().trim()
    ].where((t) => t.isNotEmpty).toList();
    // Area e turno scelti nel modulo. Finche' non c'e' un tavolo assegnato,
    // l'area del tavolo non esiste: senza questa, la colonna diceva solo "—"
    // e la scelta del cliente non si vedeva da nessuna parte.
    final scelte = ScelteModulo.da(booking['internal_notes']);
    // L'ora di arrivo arriva dal database in UTC: senza toLocal() sarebbe
    // indietro di due ore e sembrerebbe sbagliata.
    final arrivata = DateTime.tryParse((booking['created_at'] ?? '').toString())?.toLocal();
    final areaMostrata = areaName.isNotEmpty ? areaName : scelte.area;

    // Colonna Stato — estratta fuori dal GestureDetector del dettaglio
    Widget statoColumn = SizedBox(
      width: 70,
      child: isPending
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                // Verde accetta, rosso rifiuta: erano tutti e due rossi, e nel
                // gesto veloce di fine servizio si sbaglia bottone.
                behavior: HitTestBehavior.opaque,
                onTap: () => onStatusChange?.call('approved'),
                child: Container(
                  width: 30, height: 30,
                  decoration: const BoxDecoration(
                      color: AppColors.badgeGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 17),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onReject,
                child: Container(
                  width: 30, height: 30,
                  decoration: const BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 17),
                ),
              ),
            ])
          : PopupMenuButton<String>(
              color: AppColors.surface,
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'rejected') {
                  onReject?.call();
                } else {
                  onStatusChange?.call(value);
                }
              },
              itemBuilder: (_) => _kStatusChoices.map((choice) {
                final isCurrent = choice.$1 == status;
                return PopupMenuItem<String>(
                  value: choice.$1 == 'rejected' ? 'rejected' : choice.$1,
                  child: Container(
                    color: isCurrent
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Icon(choice.$3,
                          size: 18,
                          color: isCurrent ? AppColors.accent : AppColors.textPrimary),
                      const SizedBox(width: 10),
                      Text(choice.$2,
                          style: TextStyle(
                              color: isCurrent ? AppColors.accent : AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                    ]),
                  ),
                );
              }).toList(),
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: _statusDotColor(status)),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down,
                      size: 14, color: AppColors.textMuted),
                ]),
              ),
            ),
    );

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Area tappabile per dettaglio (tutto tranne Stato)
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Colonna ora — teal
              Container(
                width: 72,
                color: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Su piu' giorni l'ora da sola non dice quando: serve la
                    // data, e l'orario di fine diventa il dettaglio meno utile.
                    if (mostraData)
                      Text(
                        DateFormat('EEE d MMM', 'it_IT')
                            .format(DateTime.tryParse(booking['date']?.toString() ?? '') ??
                                DateTime.now())
                            .toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    Text(timeStart,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    if (timeEnd.isNotEmpty && !mostraData)
                      Text(timeEnd,
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              // Persone (P)
              SizedBox(
                width: 78,
                child: Center(
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: partySize >= 3
                          ? AppColors.gold
                          : Colors.transparent,
                      border: partySize < 3
                          ? Border.all(
                              color: AppColors.gold.withValues(alpha: 0.7))
                          : null,
                    ),
                    child: Center(
                      child: Text('$partySize',
                          style: TextStyle(
                              color: partySize >= 3
                                  ? Colors.white
                                  : AppColors.goldDark,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
              // Nome e Cognome, coi tag del cliente accanto
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(guestName,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis),
                        ),
                        for (final e in etichette.take(3)) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.goldLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                            ),
                            child: Text(e,
                                style: const TextStyle(
                                    color: AppColors.goldDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                        // Gli altri si contano, per non spingere via il nome
                        if (etichette.length > 3) ...[
                          const SizedBox(width: 6),
                          Text('+${etichette.length - 3}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ]),
                      // Quando e' entrata la richiesta: guardando l'elenco per
                      // ordine di arrivo e' il dato che conta.
                      if (mostraArrivo && arrivata != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Arrivata ${DateFormat("d MMM 'alle' HH:mm", 'it_IT').format(arrivata)}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Turno scelto nel modulo, per esteso
              SizedBox(
                width: 160,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: scelte.turno.isEmpty
                        ? const Text('—',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14))
                        : Text(scelte.turno,
                            softWrap: true,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.35,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              // Tavolo
              SizedBox(
                width: 86,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: (tableName.isEmpty && areaMostrata.isEmpty)
                      ? const Center(
                          child: Text('—',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 14)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (areaMostrata.isNotEmpty)
                              Text(areaMostrata.toUpperCase(),
                                  style: TextStyle(
                                      color: tableName.isEmpty
                                          ? AppColors.goldDark
                                          : AppColors.textSecondary,
                                      fontSize: 11,
                                      letterSpacing: 0.3,
                                      fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            if (tableName.isNotEmpty)
                              Container(
                                width: 32, height: 32,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.textPrimary),
                                child: Center(
                                  child: Text(tableName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                ),
                              )
                            else
                              // Area richiesta, tavolo ancora da assegnare
                              const Text('da assegnare',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                ),
              ),
            ]),
          ),
        ),
        statoColumn,
      ]),
    );
  }
}

// ── Booking Detail Sheet ──────────────────────────────────────────────────────
class BookingDetailSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onSaved;
  const BookingDetailSheet({required this.booking, required this.onSaved});

  @override
  State<BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends State<BookingDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  late TextEditingController _nomeCtrl, _cognomeCtrl, _phoneCtrl, _emailCtrl, _noteCtrl, _msgCtrl;
  late DateTime _editDate;
  late String _editTime;
  late int _editPartySize;
  late String _editStatus, _editSource;
  String? _editTableId;
  String _editTableName = '';
  int _editTableCapacity = 0;
  ScelteModulo _scelte = const ScelteModulo();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final b = widget.booking;
    _editDate = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
    _editTime = b['time_start']?.toString().substring(0, 5) ?? '20:00';
    _editPartySize = (b['party_size'] as int?) ?? 2;
    _editStatus = (b['status'] as String?) ?? 'approved';
    _editSource = (b['source'] as String?) ?? 'phone';
    _editTableId = b['table_id'] as String?;
    _scelte = ScelteModulo.da(b['internal_notes']);
    final t = b['tables'] as Map<String, dynamic>?;
    _editTableName = t?['name']?.toString() ?? '';
    _editTableCapacity = (t?['capacity'] as int?) ?? 0;
    final g = b['guests'];
    _nomeCtrl = TextEditingController(text: (g?['first_name'] ?? '').toString());
    _cognomeCtrl = TextEditingController(text: (g?['surname'] ?? '').toString().toUpperCase());
    _phoneCtrl = TextEditingController(text: (g?['phone'] ?? '').toString());
    _emailCtrl = TextEditingController(text: (g?['email'] ?? '').toString());
    _noteCtrl = TextEditingController(text: (b['notes'] ?? '').toString());
    _msgCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeCtrl.dispose(); _cognomeCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _noteCtrl.dispose(); _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final guestId = widget.booking['guest_id'];
      if (guestId != null) {
        await _supabase.from('guests').update({
          'first_name': _nomeCtrl.text.trim(),
          'surname': _cognomeCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
        }).eq('id', guestId);
      }
      final dateStr = DateFormat('yyyy-MM-dd').format(_editDate);
      await _supabase.from('bookings').update({
        'date': dateStr,
        'time_start': '$_editTime:00',
        'party_size': _editPartySize,
        'status': _editStatus,
        'source': _editSource,
        'notes': _noteCtrl.text.trim(),
        'table_id': _editTableId,
      }).eq('id', widget.booking['id']);
      // L'email parte solo al passaggio ad "accettata", mai al cambio di tavolo
      if (_editStatus == 'approved' && widget.booking['status'] != 'approved') {
        sendBookingAcceptedEmail({
          ...widget.booking,
          'date': dateStr,
          'time_start': '$_editTime:00',
          'party_size': _editPartySize,
          'notes': _noteCtrl.text.trim(),
          'guests': {
            ...?(widget.booking['guests'] as Map<String, dynamic>?),
            'first_name': _nomeCtrl.text.trim(),
            'surname': _cognomeCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
          },
        });
      }
      widget.onSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prenotazione salvata'), backgroundColor: AppColors.badgeGreen),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTable() async {
    final tables = await Supabase.instance.client
        .from('tables')
        .select('id, name, capacity, areas(name)')
        .eq('restaurant_id', '2b126a92-24d5-4e83-b38c-dfc82035a0cf')
        .order('name');
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.block, color: AppColors.textMuted),
            title: const Text('Nessun tavolo', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              setState(() { _editTableId = null; _editTableName = ''; _editTableCapacity = 0; });
              Navigator.pop(context);
            },
          ),
          ...tables.map((t) {
            final areaName = (t['areas'] as Map?)?['name']?.toString() ?? '';
            return ListTile(
              leading: Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textPrimary),
                child: Center(child: Text(t['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              ),
              title: Text('Tavolo ${t['name']}', style: const TextStyle(color: AppColors.textPrimary)),
              subtitle: areaName.isNotEmpty ? Text(areaName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)) : null,
              trailing: Text('${t['capacity']} posti', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              onTap: () {
                setState(() {
                  _editTableId = t['id'] as String;
                  _editTableName = t['name']?.toString() ?? '';
                  _editTableCapacity = (t['capacity'] as int?) ?? 0;
                });
                Navigator.pop(context);
              },
            );
          }),
        ],
      ),
    );
  }

  void _changeTime(int deltaMinutes) {
    final parts = _editTime.split(':');
    int minutes = int.parse(parts[0]) * 60 + int.parse(parts[1]) + deltaMinutes;
    minutes = minutes.clamp(0, 23 * 60 + 45);
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    setState(() => _editTime = '$h:$m');
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE d MMM yyyy', 'it_IT').format(_editDate);

    return DraggableScrollableSheet(
      initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (_, sc) => Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.textPrimary, unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1),
          tabs: const [Tab(text: 'DETTAGLI'), Tab(text: 'MESSAGGI, NOTE')],
        ),
        Expanded(
          child: TabBarView(controller: _tabController, children: [
            ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              _DetailRow(label: 'Data', child: Row(children: [
                Expanded(child: Text(_cap(dateLabel), style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 20),
                    onPressed: () => setState(() => _editDate = _editDate.subtract(const Duration(days: 1)))),
                IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                    onPressed: () => setState(() => _editDate = _editDate.add(const Duration(days: 1)))),
              ])),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Ora', child: Row(children: [
                Expanded(child: Text(_editTime, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 20), onPressed: () => _changeTime(-15)),
                IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 20), onPressed: () => _changeTime(15)),
              ])),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Persone', child: Row(children: [
                Expanded(child: Text('$_editPartySize', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 20),
                    onPressed: () => setState(() => _editPartySize = (_editPartySize - 1).clamp(1, 20))),
                IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 20),
                    onPressed: () => setState(() => _editPartySize = (_editPartySize + 1).clamp(1, 20))),
              ])),
              // Cosa ha scelto il cliente compilando il modulo. Sono dati suoi,
              // non modificabili da qui: il tavolo si assegna sotto.
              if (!_scelte.vuote) ...[
                const Divider(color: AppColors.divider),
                if (_scelte.area.isNotEmpty)
                  _DetailRow(
                    label: 'Area',
                    child: Text(_scelte.area.toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                if (_scelte.turno.isNotEmpty)
                  _DetailRow(
                    label: 'Turno',
                    child: Text(_scelte.turno,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                  ),
              ],
              const Divider(color: AppColors.divider),
              GestureDetector(
                onTap: _pickTable,
                child: _DetailRow(label: 'Tavolo', child: Row(children: [
                  Expanded(
                    child: _editTableName.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.accent),
                            ),
                            child: Text(
                              _editTableCapacity > 0 ? '$_editTableName  ($_editTableCapacity posti)' : _editTableName,
                              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                            ),
                          )
                        : const Text('Tocca per assegnare un tavolo',
                            style: TextStyle(color: AppColors.gold, fontSize: 14)),
                  ),
                  const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 16),
                ])),
              ),
              const SizedBox(height: 16),
              _EditableField(label: 'Nome', controller: _nomeCtrl),
              const SizedBox(height: 8),
              _EditableField(label: 'Telefono', controller: _phoneCtrl, prefix: 'Italy (+39)', type: TextInputType.phone),
              const SizedBox(height: 8),
              _EditableField(label: 'E-mail', controller: _emailCtrl, type: TextInputType.emailAddress),
              const SizedBox(height: 8),
              _EditableField(label: 'Cognome', controller: _cognomeCtrl),
              const SizedBox(height: 16),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Stato', child: DropdownButton<String>(
                value: _editStatus,
                dropdownColor: AppColors.surface,
                underline: const SizedBox(), isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'approved', child: Text('👍 Accettato', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'seated', child: Text('🍽️ Al tavolo', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'pending', child: Text('❓ In attesa', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'canceled', child: Text('✕ Annullato', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'no_show', child: Text('🚫 No-show', style: TextStyle(color: AppColors.textPrimary))),
                ],
                onChanged: (v) => setState(() => _editStatus = v!),
              )),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Sorgente', child: DropdownButton<String>(
                value: _editSource,
                dropdownColor: AppColors.surface,
                underline: const SizedBox(), isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'phone', child: Text('📞 Telefono', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'web', child: Text('🌐 Web', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'walkin', child: Text('🚶 Walk-in', style: TextStyle(color: AppColors.textPrimary))),
                ],
                onChanged: (v) => setState(() => _editSource = v!),
              )),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Note', child: TextField(
                controller: _noteCtrl, maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              )),
              const SizedBox(height: 20),
            ]),
            // Prima: un segnaposto "Prenotazione creata" e un campo il cui
            // pulsante di invio non era collegato a nulla.
            ConversazioneCliente(bookingId: widget.booking['id'] as String),
          ]),
        ),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.booking['status'] == 'pending') ...[
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await _supabase.from('bookings')
                            .update({'status': 'approved'})
                            .eq('id', widget.booking['id']);
                        sendBookingAcceptedEmail(widget.booking);
                        if (!context.mounted) return;
                        widget.onSaved();
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accetta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => RejectionScreen(
                          booking: widget.booking,
                          onRejected: widget.onSaved,
                        ),
                      ));
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rifiuta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionBtn(icon: Icons.more_horiz, onTap: () {}),
              const SizedBox(width: 12),
              _ActionBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
              const SizedBox(width: 12),
              _saving
                  ? const CircularProgressIndicator(color: AppColors.accent)
                  : _ActionBtn(icon: Icons.check, color: AppColors.accent, onTap: _save),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label; final Widget child;
  const _DetailRow({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 4), child,
    ]),
  );
}

class _EditableField extends StatelessWidget {
  final String label; final TextEditingController controller;
  final String? prefix; final TextInputType? type;
  const _EditableField({required this.label, required this.controller, this.prefix, this.type});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      const SizedBox(height: 2),
      Row(children: [
        if (prefix != null) ...[
          Text(prefix!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 6),
        ],
        Expanded(child: TextField(controller: controller, keyboardType: type,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
      ]),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color? color;
  const _ActionBtn({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: color ?? AppColors.divider, shape: BoxShape.circle),
      child: Icon(icon, color: AppColors.textPrimary, size: 22),
    ),
  );
}

// ── BookingCard (public widget usato da ReservationsScreen) ──────────────────
class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final Future<void> Function(String status) onStatusChange;

  const BookingCard({super.key, required this.booking, required this.onStatusChange});

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return AppColors.statoConfermato;
      case 'pending':   return AppColors.statoAttesa;
      case 'seated':    return AppColors.statoAlTavolo;
      case 'left':      return AppColors.statoConcluso;
      case 'no_show':    return AppColors.statoAnnullato;
      case 'walkin':    return AppColors.gold;
      default:          return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStart = booking.timeStart.length >= 5 ? booking.timeStart.substring(0, 5) : booking.timeStart;
    final partySize = booking.partySize;
    final statusColor = _statusColor(booking.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        SizedBox(
          width: 48,
          child: Text(timeStart,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(booking.guestName,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textSecondary.withOpacity(0.5)),
          ),
          child: Center(
            child: Text('$partySize',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
      ]),
    );
  }
}

/// Nome, indirizzo, telefono e e-mail letti dal profilo del ristorante
/// (Impostazioni > Profilo ristorante), usati nelle email al cliente.
/// Erano scritti fissi nel codice: correggendo il profilo le email non
/// cambiavano, e mostravano un numero di telefono non più valido.
/// Nessuna cache: così una modifica al profilo vale dall'email successiva.
Future<Map<String, dynamic>> datiRistorante() async {
  const vuoti = {
    'restaurantName': 'Hio Oriental Bar',
    'restaurantAddress': '',
    'restaurantCity': '',
    'restaurantPhone': '',
    'restaurantEmail': '',
  };
  try {
    final r = await Supabase.instance.client
        .from('restaurants')
        .select('name, address, city, phone, email')
        .eq('id', '2b126a92-24d5-4e83-b38c-dfc82035a0cf')
        .single();
    return {
      'restaurantName': (r['name'] ?? 'Hio Oriental Bar').toString(),
      'restaurantAddress': (r['address'] ?? '').toString(),
      'restaurantCity': (r['city'] ?? '').toString(),
      'restaurantPhone': (r['phone'] ?? '').toString(),
      'restaurantEmail': (r['email'] ?? '').toString(),
    };
  } catch (e) {
    debugPrint('lettura profilo ristorante fallita: $e');
    return vuoti;
  }
}

/// Email al cliente quando la prenotazione viene ACCETTATA.
/// Non fa riferimento al tavolo: l'assegnazione è interna e può cambiare
/// in qualsiasi momento senza che il cliente ne debba sapere nulla.
Future<void> sendBookingAcceptedEmail(Map<String, dynamic> booking) async {
  final g = booking['guests'];
  final email = g?['email'] as String?;
  if (email == null || email.isEmpty) return;

  String turno = '', area = '';
  try {
    final raw = booking['internal_notes'] as String? ?? '';
    if (raw.startsWith('{')) {
      final pattern = RegExp(r'"(\w+)"\s*:\s*"([^"]*)"');
      for (final m in pattern.allMatches(raw)) {
        if (m.group(1) == 'turno') turno = m.group(2) ?? '';
        if (m.group(1) == 'area') area = m.group(2) ?? '';
      }
    }
  } catch (_) {}

  try {
    final guestId = booking['guest_id'];
    if (guestId != null) {
      try {
        await Supabase.instance.client.rpc('increment_visits_count', params: {'guest_id': guestId});
      } catch (_) {}
    }
    final ristorante = await datiRistorante();
    await Supabase.instance.client.functions.invoke('send-table-assigned-email', body: {
      'email': email,
      'nome': g?['first_name'] ?? '',
      'cognome': g?['surname'] ?? '',
      'phone': g?['phone'] ?? '',
      'date': booking['date'] ?? '',
      'time': (booking['time_start'] ?? '').toString().substring(0, 5),
      'persons': booking['party_size'] ?? 0,
      'notes': booking['notes'] ?? '',
      'turno': turno,
      'area': area,
      ...ristorante,
      'bookingId': booking['id'],
    });
  } catch (e) {
    debugPrint('send-table-assigned-email error: $e');
  }
}

// ── Rejection Screen ──────────────────────────────────────────────────────────
class RejectionScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onRejected;
  const RejectionScreen({super.key, required this.booking, required this.onRejected});
  @override
  State<RejectionScreen> createState() => _RejectionScreenState();
}

class _RejectionScreenState extends State<RejectionScreen> {
  static const _motivi = [
    ('Al completo', 'Siamo al completo. Possiamo proporti un giorno o un orario diverso?'),
    ('Chiuso', 'Quel giorno saremo chiusi. Possiamo proporti un giorno diverso?'),
    ('Altro', 'Purtroppo non possiamo accettare la tua prenotazione perché'),
  ];

  String _selectedMotivo = 'Al completo';
  late TextEditingController _msgCtrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController(text: _motivi[0].$2);
  }

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  void _onMotivoChanged(String? value) {
    if (value == null) return;
    final match = _motivi.firstWhere((m) => m.$1 == value, orElse: () => _motivi[0]);
    setState(() {
      _selectedMotivo = value;
      _msgCtrl.text = match.$2;
    });
  }

  Future<void> _confirm() async {
    setState(() => _sending = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('bookings').update({'status': 'canceled'}).eq('id', widget.booking['id']);
      final g = widget.booking['guests'];
      final email = g?['email'] as String? ?? '';
      if (email.isNotEmpty) {
        try {
          await supabase.functions.invoke('send-rejection-email', body: {
            'email': email,
            'nome': g?['first_name'] ?? '',
            'cognome': g?['surname'] ?? '',
            'motivo': _selectedMotivo,
            'messaggio': _msgCtrl.text.trim(),
            // Senza data e ora il cliente con piu' richieste non sa quale è stata rifiutata
            'date': widget.booking['date'] ?? '',
            'time': (widget.booking['time_start'] ?? '').toString(),
            'persons': widget.booking['party_size'] ?? 0,
            ...await datiRistorante(),
          });
        } catch (e) { debugPrint('send-rejection-email error: $e'); }
      }
      if (mounted) { Navigator.pop(context); widget.onRejected(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Perché rifiuti la prenotazione?',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Invia un messaggio all\'ospite o utilizza uno dei nostri messaggi standard in base al motivo.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 32),
            // Dropdown Motivo
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text('Motivo', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                DropdownButton<String>(
                  value: _selectedMotivo,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  items: _motivi.map((m) => DropdownMenuItem(
                    value: m.$1,
                    child: Text(m.$1, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                  )).toList(),
                  onChanged: _onMotivoChanged,
                ),
              ]),
            ),
            const SizedBox(height: 16),
            // Messaggio editabile
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text('Messaggio all\'utente', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(12, 4, 12, 12),
                  ),
                ),
              ]),
            ),
            const Spacer(),
            Row(children: [
              ElevatedButton.icon(
                onPressed: _sending ? null : _confirm,
                icon: const Icon(Icons.thumb_down, size: 18),
                label: const Text('Rifiuta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  // Azione distruttiva: era verde, colore che qui significa "accetta"
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Conversazione con il cliente ──────────────────────────────────────────────
/// Legge e scrive nella tabella `booking_messages`, la stessa usata dalla
/// pagina di riepilogo che il cliente riceve via email.
///
/// Prima l'app scriveva nel campo `notes` della prenotazione: sovrascriveva
/// la nota lasciata in fase di prenotazione, e il cliente vedeva la risposta
/// del locale attribuita a sé stesso. I messaggi che il cliente scriveva,
/// dal canto loro, non arrivavano da nessuna parte.
class ConversazioneCliente extends StatefulWidget {
  final String bookingId;
  const ConversazioneCliente({super.key, required this.bookingId});

  @override
  State<ConversazioneCliente> createState() => _ConversazioneClienteState();
}

class _ConversazioneClienteState extends State<ConversazioneCliente> {
  final _supabase = Supabase.instance.client;
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _messaggi = [];
  bool _caricamento = true;
  bool _invio = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() { _caricamento = true; _errore = null; });
    try {
      final res = await _supabase
          .from('booking_messages')
          .select('id, sender, message, created_at')
          .eq('booking_id', widget.bookingId)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _messaggi = List<Map<String, dynamic>>.from(res);
        _caricamento = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _errore = e.toString(); _caricamento = false; });
    }
  }

  Future<void> _invia() async {
    final testo = _ctrl.text.trim();
    if (testo.isEmpty || _invio) return;
    setState(() => _invio = true);
    try {
      await _supabase.from('booking_messages').insert({
        'booking_id': widget.bookingId,
        'sender': 'restaurant',
        'message': testo,
      });
      _ctrl.clear();
      await _carica();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Messaggio non inviato: $e'), backgroundColor: AppColors.accent),
        );
      }
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  String _quando(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    return DateFormat('d MMM, HH:mm', 'it_IT').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: _caricamento
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : _errore != null
                ? _Avviso(testo: 'Messaggi non caricati.\n$_errore', onRiprova: _carica)
                : _messaggi.isEmpty
                    ? const _Avviso(testo: 'Nessun messaggio.\nQui compaiono i messaggi scambiati con il cliente.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messaggi.length,
                        itemBuilder: (_, i) {
                          final m = _messaggi[i];
                          final delCliente = m['sender'] == 'guest';
                          return Align(
                            alignment: delCliente ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                              decoration: BoxDecoration(
                                color: delCliente ? AppColors.cardLight : AppColors.accent,
                                borderRadius: BorderRadius.circular(12),
                                border: delCliente ? Border.all(color: AppColors.divider) : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (m['message'] ?? '').toString(),
                                    style: TextStyle(
                                      color: delCliente ? AppColors.textPrimary : Colors.white,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${delCliente ? 'Cliente' : 'Ristorante'} · ${_quando(m['created_at']?.toString())}',
                                    style: TextStyle(
                                      color: delCliente ? AppColors.textMuted : Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
      Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _ctrl,
            minLines: 1, maxLines: 4,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Rispondi al cliente...',
              hintStyle: TextStyle(color: AppColors.textMuted),
              border: InputBorder.none, isDense: true,
            ),
          )),
          IconButton(
            icon: _invio
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                : const Icon(Icons.send, color: AppColors.accent, size: 22),
            onPressed: _invio ? null : _invia,
          ),
        ]),
      ),
    ]);
  }
}

class _Avviso extends StatelessWidget {
  final String testo;
  final VoidCallback? onRiprova;
  const _Avviso({required this.testo, this.onRiprova});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(testo, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
          if (onRiprova != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRiprova, child: const Text('Riprova')),
          ],
        ]),
      ),
    );
  }
}


/// Una cella dell'intestazione della tabella.
///
/// Maiuscoletto spaziato: le intestazioni si leggono a colpo d'occhio e non si
/// confondono con i dati, senza doverle ingrandire.
class _Intestazione extends StatelessWidget {
  final double? larghezza;
  final String testo;
  final double sinistra;
  final bool centrata;
  const _Intestazione({
    this.larghezza,
    required this.testo,
    this.sinistra = 0,
    this.centrata = false,
  });

  @override
  Widget build(BuildContext context) {
    final etichetta = Text(
      testo.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
    final contenuto = centrata
        ? Center(child: etichetta)
        : Padding(padding: EdgeInsets.only(left: sinistra), child: etichetta);
    return larghezza == null
        ? Expanded(child: contenuto)
        : SizedBox(width: larghezza, child: contenuto);
  }
}

// ── Menu della giornata ──────────────────────────────────────────────────────
// `StatoGiornata` e le regole stanno in stato_giornata.dart, condivise col
// calendario.

/// I tre puntini in alto a destra. Da qui si aprono e si chiudono le
/// prenotazioni dal sito: prima era un badge accanto alla data.
class _MenuGiornata extends StatelessWidget {
  final StatoGiornata stato;
  final bool inCorso;
  final String? motivo;
  final VoidCallback onCambia;
  const _MenuGiornata({
    required this.stato,
    required this.inCorso,
    required this.motivo,
    required this.onCambia,
  });

  @override
  Widget build(BuildContext context) {
    final modificabile = stato == StatoGiornata.aperte || stato == StatoGiornata.chiuse;
    final aperte = stato == StatoGiornata.aperte;

    final (IconData icona, Color colore) = switch (stato) {
      StatoGiornata.aperte => (Icons.lock_open_outlined, AppColors.statoConfermato),
      StatoGiornata.chiuse => (Icons.lock_outline, AppColors.accent),
      StatoGiornata.nonAncoraAperte => (Icons.schedule_outlined, AppColors.textSecondary),
      StatoGiornata.chiusuraSettimanale => (Icons.event_busy_outlined, AppColors.textSecondary),
      _ => (Icons.hourglass_empty, AppColors.textMuted),
    };

    // Il titolo dice l'azione quando si puo' agire, lo stato quando no.
    final titolo = modificabile
        ? (aperte ? 'Chiudi le prenotazioni online' : 'Riapri le prenotazioni online')
        : 'Prenotazioni online';

    final spiegazione = switch (stato) {
      StatoGiornata.aperte => 'Ora il sito accetta prenotazioni per questa giornata.',
      StatoGiornata.chiuse =>
        "Ora il sito non le accetta. Voi potete comunque inserirle dall'app.",
      StatoGiornata.chiusuraSettimanale =>
        'Giorno di chiusura settimanale. Si cambia da Impostazioni → Orari di apertura.',
      StatoGiornata.nonAncoraAperte =>
        motivo ?? 'Il sito non accetta ancora prenotazioni per questa data.',
      _ => 'Stato non ancora disponibile.',
    };

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
      tooltip: 'Altre azioni',
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (_) => onCambia(),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'prenotazioni',
          enabled: modificabile && !inCorso,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (inCorso)
                const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
              else
                Icon(icona, size: 18, color: colore),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titolo,
                      style: TextStyle(
                          color: modificabile ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(spiegazione,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12, height: 1.3)),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
