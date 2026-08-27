import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/azioni_barra.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';
import 'package:restaurant_booking/shared/widgets/logo_hio.dart';

const _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _loading = true;
  int _oggiPrenotazioni = 0;
  int _oggiOspiti = 0;
  int _settimanaPrenotazioni = 0;
  int _settimanaOspiti = 0;
  int _mesePrenotazioni = 0;
  int _meseOspiti = 0;
  int _annoPrenotazioni = 0;
  int _annoOspiti = 0;
  int _arrivateOggi = 0;
  int _arrivateOggiOspiti = 0;
  int _daAssegnare = 0;

  // ── Stasera ────────────────────────────────────────────────────────────
  /// Coperti e tavoli per turno: 'aperitivo', 'primo', 'secondo', 'altro'.
  Map<String, (int, int)> _turniStasera = {};
  int _copertiStasera = 0;
  int _postiTotali = 0;
  int _abitualiStasera = 0;
  int _primaVoltaStasera = 0;
  int _noteStasera = 0;

  // ── Da fare ────────────────────────────────────────────────────────────
  int _daApprovare = 0;
  int _senzaTavolo = 0;
  int _messaggiRecenti = 0;

  // ── La settimana ───────────────────────────────────────────────────────
  /// Coperti giorno per giorno, da oggi in avanti.
  List<(DateTime, int)> _settimana = [];

  String _nomeLocale = '';
  String _indirizzoLocale = '';

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _channel = Supabase.instance.client
        .channel('dashboard-bookings')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'restaurant_id',
            value: _restaurantId,
          ),
          callback: (_) => _loadStats(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final oggi = DateTime.now();
      final oggiStr = DateFormat('yyyy-MM-dd').format(oggi);
      final tra7Str = DateFormat('yyyy-MM-dd').format(oggi.add(const Duration(days: 7)));

      // Query oggi
      final oggiRes = await supabase
          .from('bookings')
          .select('party_size')
          .eq('restaurant_id', _restaurantId)
          .eq('date', oggiStr)
          .inFilter('status', ['approved', 'pending']);

      // Query prossimi 7 giorni. La data serve anche a disegnare la striscia
      // dei giorni: senza, i coperti sarebbero un totale e basta.
      final settimanaRes = await supabase
          .from('bookings')
          .select('party_size, date')
          .eq('restaurant_id', _restaurantId)
          .gte('date', oggiStr)
          .lte('date', tra7Str)
          .inFilter('status', ['approved', 'pending']);

      // Mese e anno contano tutto il periodo, non solo da oggi in avanti:
      // servono a vedere l'andamento, quindi comprendono anche il passato.
      final primoDelMese = DateFormat('yyyy-MM-dd').format(DateTime(oggi.year, oggi.month, 1));
      final ultimoDelMese = DateFormat('yyyy-MM-dd').format(DateTime(oggi.year, oggi.month + 1, 0));
      final primoDellAnno = '${oggi.year}-01-01';
      final ultimoDellAnno = '${oggi.year}-12-31';

      final meseRes = await supabase
          .from('bookings')
          .select('party_size')
          .eq('restaurant_id', _restaurantId)
          .gte('date', primoDelMese)
          .lte('date', ultimoDelMese)
          .inFilter('status', ['approved', 'pending']);

      final annoRes = await supabase
          .from('bookings')
          .select('party_size')
          .eq('restaurant_id', _restaurantId)
          .gte('date', primoDellAnno)
          .lte('date', ultimoDellAnno)
          .inFilter('status', ['approved', 'pending']);

      // Nome e indirizzo per la fascia in fondo: presi dal profilo, non
      // scritti nel codice, cosi' cambiando l'insegna cambiano dappertutto.
      final profilo = await supabase
          .from('restaurants')
          .select('name, address, city')
          .eq('id', _restaurantId)
          .maybeSingle();

      // Entrate oggi, in qualunque stato e per qualunque data futura: e' la
      // domanda "cosa mi e' passato per le mani oggi", che l'app organizzata
      // per data di servizio non sapeva rispondere.
      final inizioOggi = DateTime(oggi.year, oggi.month, oggi.day);
      final arrivateRes = await supabase
          .from('bookings')
          .select('party_size')
          .eq('restaurant_id', _restaurantId)
          .gte('created_at', inizioOggi.toIso8601String());

      // Query da assegnare (web, senza tavolo)
      final daAssegnareRes = await supabase
          .from('bookings')
          .select('id')
          .eq('restaurant_id', _restaurantId)
          .eq('source', 'web')
          .eq('status', 'pending');

      // Il servizio di stasera, non solo il suo conteggio: turni, tavoli e
      // chi arriva. Sono le cose che si guardano alle sei del pomeriggio.
      final staseraRes = await supabase
          .from('bookings')
          .select('party_size, time_start, internal_notes, table_id, notes, '
              'guests(visits_count, tags)')
          .eq('restaurant_id', _restaurantId)
          .eq('date', oggiStr)
          .inFilter('status', ['approved', 'pending', 'seated']);

      // Capienza vera, per dire quanto e' piena la serata.
      final tavoliRes = await supabase
          .from('tables')
          .select('capacity, is_active')
          .eq('restaurant_id', _restaurantId);

      // Le cose in sospeso, oggi sparse fra campanella e riquadro rosso.
      final daApprovareRes = await supabase
          .from('bookings')
          .select('id')
          .eq('restaurant_id', _restaurantId)
          .eq('status', 'pending')
          .gte('date', oggiStr);

      final senzaTavoloRes = await supabase
          .from('bookings')
          .select('id')
          .eq('restaurant_id', _restaurantId)
          .isFilter('table_id', null)
          .gte('date', oggiStr)
          .inFilter('status', ['approved', 'pending']);

      // `booking_messages` non tiene traccia di cosa e' stato letto, quindi
      // si contano quelli recenti e non quelli "non letti": dire non letti
      // sarebbe una mezza verita'.
      final messaggiRes = await supabase
          .from('booking_messages')
          .select('id')
          .eq('sender', 'guest')
          .gte('created_at',
              oggi.subtract(const Duration(days: 7)).toIso8601String());

      int sommaOspiti(List<dynamic> righe) {
        var totale = 0;
        for (final r in righe) {
          totale += ((r as Map)['party_size'] as int? ?? 0);
        }
        return totale;
      }

      // ── Stasera, per turno ───────────────────────────────────────────────
      final turni = <String, (int, int)>{};
      var abituali = 0, primaVolta = 0, conNote = 0;
      for (final r in staseraRes) {
        final b = r as Map;
        final t = _turnoDi(b);
        final (coperti, tavoli) = turni[t] ?? (0, 0);
        turni[t] = (coperti + ((b['party_size'] as int?) ?? 0), tavoli + 1);

        final g = b['guests'] as Map?;
        // Le visite si contano all'accettazione, quindi questa prenotazione
        // e' gia' dentro: "abituale" vuol dire che ne aveva altre prima.
        final visite = (g?['visits_count'] as int?) ?? 0;
        if (visite > 1) {
          abituali++;
        } else {
          primaVolta++;
        }
        if ((b['notes'] ?? '').toString().trim().isNotEmpty) conNote++;
      }

      var posti = 0;
      for (final t in tavoliRes as List) {
        if ((t as Map)['is_active'] == false) continue;
        posti += (t['capacity'] as int?) ?? 0;
      }

      // ── La settimana, giorno per giorno ─────────────────────────────────
      final perGiorno = <String, int>{};
      for (final r in settimanaRes) {
        final d = ((r as Map)['date'] ?? '').toString();
        perGiorno[d] = (perGiorno[d] ?? 0) + ((r['party_size'] as int?) ?? 0);
      }
      final giorni = <(DateTime, int)>[];
      for (var i = 0; i < 7; i++) {
        final g = DateTime(oggi.year, oggi.month, oggi.day + i);
        giorni.add((g, perGiorno[DateFormat('yyyy-MM-dd').format(g)] ?? 0));
      }

      setState(() {
        _oggiPrenotazioni = oggiRes.length;
        _oggiOspiti = sommaOspiti(oggiRes);
        _settimanaPrenotazioni = settimanaRes.length;
        _settimanaOspiti = sommaOspiti(settimanaRes);
        _mesePrenotazioni = meseRes.length;
        _meseOspiti = sommaOspiti(meseRes);
        _annoPrenotazioni = annoRes.length;
        _annoOspiti = sommaOspiti(annoRes);
        _arrivateOggi = arrivateRes.length;
        _arrivateOggiOspiti = sommaOspiti(arrivateRes);
        _daAssegnare = daAssegnareRes.length;
        _turniStasera = turni;
        _copertiStasera = sommaOspiti(staseraRes);
        _postiTotali = posti;
        _abitualiStasera = abituali;
        _primaVoltaStasera = primaVolta;
        _noteStasera = conNote;
        _daApprovare = daApprovareRes.length;
        _senzaTavolo = senzaTavoloRes.length;
        _messaggiRecenti = messaggiRes.length;
        _settimana = giorni;
        _nomeLocale = (profilo?['name'] ?? '').toString();
        _indirizzoLocale = [profilo?['address'], profilo?['city']]
            .where((v) => (v ?? '').toString().trim().isNotEmpty)
            .join(', ');
        _loading = false;
      });
    } catch (e) {
      debugPrint('Dashboard stats error: $e');
      setState(() => _loading = false);
    }
  }

  /// A quale turno appartiene una prenotazione.
  ///
  /// Stessa regola dell'elenco e dei rapporti: quelle prese al telefono non
  /// hanno un turno scelto e si collocano sull'orario, altrimenti finirebbero
  /// tutte in "altro".
  static String _turnoDi(Map b) {
    final grezzo = (b['internal_notes'] ?? '').toString().toUpperCase();
    if (grezzo.contains('APERITIF') || grezzo.contains('APERITIVO')) {
      return 'aperitivo';
    }
    if (grezzo.contains('1°') || grezzo.contains('1 TURNO')) return 'primo';
    if (grezzo.contains('2°') || grezzo.contains('2 TURNO')) return 'secondo';
    final ora = (b['time_start'] ?? '').toString();
    if (ora.startsWith('18') || ora.startsWith('19')) return 'aperitivo';
    if (ora.startsWith('20') || ora.startsWith('21')) return 'primo';
    if (ora.startsWith('22') || ora.startsWith('23')) return 'secondo';
    return 'altro';
  }

  /// Le scorciatoie: tre per riga su schermo largo, due sul telefono.
  ///
  /// Tutte alla stessa altezza dentro la riga, altrimenti quella con
  /// l'etichetta su due righe alzerebbe da sola la fila.
  Widget _grigliaScorciatoie(bool schermoLargo, List<Widget> voci) {
    final colonne = schermoLargo ? 3 : 2;
    final righe = <Widget>[];
    for (var i = 0; i < voci.length; i += colonne) {
      final fetta = voci.sublist(i, (i + colonne).clamp(0, voci.length));
      righe.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var c = 0; c < colonne; c++) ...[
            if (c > 0) const SizedBox(width: 10),
            Expanded(child: c < fetta.length ? fetta[c] : const SizedBox()),
          ],
        ]),
      ));
      righe.add(const SizedBox(height: 10));
    }
    return Column(children: righe);
  }

  /// Dispone le schede una sotto l'altra sul telefono, due per riga quando
  /// c'e' spazio. Su un monitor largo quattro lenzuoli impilati costringono a
  /// scorrere per vedere numeri che starebbero benissimo affiancati.
  Widget _griglia(bool schermoLargo, List<Widget> schede) {
    if (!schermoLargo) {
      return Column(children: [
        for (final s in schede) ...[s, const SizedBox(height: 12)],
      ]);
    }
    final righe = <Widget>[];
    for (var i = 0; i < schede.length; i += 2) {
      righe.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: schede[i]),
          const SizedBox(width: 12),
          if (i + 1 < schede.length)
            Expanded(child: schede[i + 1])
          else
            const Expanded(child: SizedBox()),
        ]),
      ));
      righe.add(const SizedBox(height: 12));
    }
    return Column(children: righe);
  }

  @override
  Widget build(BuildContext context) {
    final oggi = DateFormat('d. MMM', 'it_IT').format(DateTime.now());
    final tra7 = DateFormat('d. MMM', 'it_IT').format(DateTime.now().add(const Duration(days: 7)));
    final nomeMese = DateFormat('MMMM', 'it_IT').format(DateTime.now());
    final mese = nomeMese[0].toUpperCase() + nomeMese.substring(1);
    final stretto = MediaQuery.of(context).size.width < 480;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      // Fascia nera col logo, come l'intestazione del modulo che vede il
      // cliente: aprendo l'app si riconosce lo stesso locale.
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        elevation: 0,
        // Il logo intero non entra nei 56 punti standard di una barra, e nemmeno
        // negli 84 di prima: il marchio e' disegnato a filo di capello e sotto
        // i 90 punti di altezza i tratti scendono sotto il pixel e sbiadiscono.
        // Provato riducendo l'originale a 56 e a 96: a 56 e' illeggibile.
        toolbarHeight: stretto ? 84 : 116,
        // Su schermo stretto il logo centrato finirebbe a contendersi lo
        // spazio con le tre icone: li' si appoggia a sinistra e rimpicciolisce.
        centerTitle: !stretto,
        titleSpacing: stretto ? 0 : null,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        // Lo stesso logo dell'avvio e della schermata di accesso, dove su nero
        // si legge bene. Il marchio ha tratti sottili: sotto una certa
        // dimensione svanisce, quindi la barra si alza per contenerlo intero
        // invece di rimpicciolirlo.
        title: LogoHio(altezza: stretto ? 62 : 92),
        actions: [
          ...azioniBarra(context),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: _loadStats,
        // Il pannello nasce per il telefono. Su un monitor largo, stirato a
        // tutta pagina, le schede diventano lenzuoli e i numeri si perdono nel
        // vuoto: qui si tiene una larghezza leggibile e si sta al centro, come
        // fa il modulo di prenotazione.
        child: LayoutBuilder(builder: (context, vincoli) {
          final schermoLargo = vincoli.maxWidth >= 760;
          return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // In cima perche' e' l'unica voce che chiede di fare qualcosa:
              // le altre raccontano, questa aspetta.
              GestureDetector(
                onTap: () => context.go('/bookings?filter=da_assegnare'),
                child: _DaAssegnareCard(count: _daAssegnare, loading: _loading),
              ),
              const SizedBox(height: 24),
              // Le cose in sospeso, tutte insieme. Quando non ce n'e' il
              // pannello sparisce invece di restare a occupare spazio.
              if (!_loading && (_daApprovare + _senzaTavolo + _messaggiRecenti) > 0) ...[
                _DaFareCard(
                  daApprovare: _daApprovare,
                  senzaTavolo: _senzaTavolo,
                  messaggi: _messaggiRecenti,
                ),
                const SizedBox(height: 16),
              ],
              _StaseraCard(
                turni: _turniStasera,
                coperti: _copertiStasera,
                postiTotali: _postiTotali,
                abituali: _abitualiStasera,
                primaVolta: _primaVoltaStasera,
                conNote: _noteStasera,
                loading: _loading,
                onTap: () {
                  final today = DateTime.now();
                  ref.read(selectedDateProvider.notifier).state = today;
                  context.go('/reservations');
                },
              ),
              const SizedBox(height: 16),
              _SettimanaCard(
                giorni: _settimana,
                loading: _loading,
                onGiorno: (g) {
                  ref.read(selectedDateProvider.notifier).state = g;
                  context.go('/bookings?date=${DateFormat('yyyy-MM-dd').format(g)}');
                },
              ),
              const SizedBox(height: 24),
              const Text('Scorciatoie', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _grigliaScorciatoie(schermoLargo, [
                _ShortcutButton(icon: Icons.calendar_today_outlined, label: 'Prenotazioni oggi', onTap: () {
                    final today = DateTime.now();
                    final dateStr = DateFormat('yyyy-MM-dd').format(today);
                    ref.read(selectedDateProvider.notifier).state = today;
                    context.go('/bookings?date=' + dateStr);
                  }),
                _ShortcutButton(icon: Icons.calendar_month_outlined, label: 'Prenotazioni questo mese', onTap: () => context.go('/calendar')),
                _ShortcutButton(icon: Icons.list_alt_outlined, label: 'Elenco prenotazioni', onTap: () => context.go('/bookings')),
                _ShortcutButton(icon: Icons.view_week_outlined, label: 'Programma di sala', onTap: () => context.go('/reservations')),
                _ShortcutButton(icon: Icons.settings_outlined, label: 'Impostazioni e componenti aggiuntivi', onTap: () => context.go('/settings')),
              ]),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('Prenotazioni', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Su schermo largo due per riga: riempiono lo spazio invece di
              // allungarsi, e si confrontano a colpo d'occhio.
              _griglia(schermoLargo, [
                _StatsCard(
                  label: 'Oggi',
                  date: oggi,
                  tinta: AppColors.accent,
                  icona: Icons.today_outlined,
                  prenotazioni: _oggiPrenotazioni,
                  ospiti: _oggiOspiti,
                  loading: _loading,
                  onTap: () {
                    final today = DateTime.now();
                    ref.read(selectedDateProvider.notifier).state = today;
                    context.go('/bookings?date=${DateFormat('yyyy-MM-dd').format(today)}');
                  },
                ),
                _StatsCard(
                  label: 'Prossimi 7 giorni',
                  tinta: AppColors.statoAlTavolo,
                  icona: Icons.date_range_outlined,
                  date: '$oggi - $tra7',
                  prenotazioni: _settimanaPrenotazioni,
                  ospiti: _settimanaOspiti,
                  loading: _loading,
                  onTap: () => context.go('/bookings?periodo=settimana'),
                ),
                _StatsCard(
                  label: 'Questo mese',
                  tinta: AppColors.badgeGreen,
                  icona: Icons.calendar_month_outlined,
                  date: mese,
                  prenotazioni: _mesePrenotazioni,
                  ospiti: _meseOspiti,
                  loading: _loading,
                  onTap: () => context.go('/bookings?periodo=mese'),
                ),
                _StatsCard(
                  label: 'Arrivate oggi',
                  tinta: AppColors.goldDark,
                  icona: Icons.inbox_outlined,
                  date: 'Richieste entrate',
                  prenotazioni: _arrivateOggi,
                  ospiti: _arrivateOggiOspiti,
                  loading: _loading,
                  onTap: () => context.go('/bookings?periodo=arrivate'),
                ),
                _StatsCard(
                  label: 'Totale ${DateTime.now().year}',
                  tinta: AppColors.textSecondary,
                  icona: Icons.insights_outlined,
                  date: 'Tutto l\'anno',
                  prenotazioni: _annoPrenotazioni,
                  ospiti: _annoOspiti,
                  loading: _loading,
                  onTap: () => context.go('/bookings?periodo=anno'),
                ),
              ]),
              const SizedBox(height: 28),
              // Fascia nera di chiusura, come il piede del modulo.
              if (_nomeLocale.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  decoration: BoxDecoration(
                    color: AppColors.nero,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    Text(
                      _nomeLocale.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 14,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_indirizzoLocale.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _indirizzoLocale,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB9B4AC), fontSize: 12),
                      ),
                    ],
                  ]),
                ),
              const SizedBox(height: 80),
            ],
          ),
          ),
          ),
        );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/bookings/new'),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

/// Com'e' fatta la serata di oggi, non quanto fa il totale.
class _StaseraCard extends StatelessWidget {
  final Map<String, (int, int)> turni;
  final int coperti, postiTotali, abituali, primaVolta, conNote;
  final bool loading;
  final VoidCallback onTap;

  const _StaseraCard({
    required this.turni,
    required this.coperti,
    required this.postiTotali,
    required this.abituali,
    required this.primaVolta,
    required this.conNote,
    required this.loading,
    required this.onTap,
  });

  static const _ordine = <(String, String)>[
    ('aperitivo', 'Aperitivo 18:30'),
    ('primo', '1º turno 20:00'),
    ('secondo', '2º turno 22:00'),
  ];

  @override
  Widget build(BuildContext context) {
    final data = DateFormat('EEEE d MMMM', 'it_IT').format(DateTime.now());
    final quota = postiTotali > 0 ? (coperti / postiTotali).clamp(0.0, 1.0) : 0.0;
    final fuoriTurno = turni['altro'];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
              AppColors.accent.withValues(alpha: 0.13), AppColors.card),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.nightlight_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Stasera',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(data,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14)),
            ),
            if (postiTotali > 0)
              Text('$coperti su $postiTotali coperti',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 14),
          if (loading)
            const SizedBox(
                height: 80,
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent)))
          else if (coperti == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Nessuna prenotazione per stasera.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            )
          else ...[
            // La barra dice quanto e' piena la sala solo se sappiamo quanti
            // posti ci sono: con le capienze a zero direbbe una bugia.
            if (postiTotali > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: quota,
                  minHeight: 10,
                  backgroundColor: AppColors.cardLight,
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(children: [
              for (final t in _ordine) ...[
                Expanded(child: _riquadroTurno(t.$2, turni[t.$1])),
                if (t != _ordine.last) const SizedBox(width: 10),
              ],
            ]),
            if (fuoriTurno != null) ...[
              const SizedBox(height: 10),
              Text('Fuori turno: ${fuoriTurno.$1} coperti su ${fuoriTurno.$2} tavoli',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (abituali > 0)
                _pastiglia('$abituali già stati qui', AppColors.goldLight,
                    AppColors.goldDark),
              if (conNote > 0)
                _pastiglia('$conNote con note', AppColors.accentLight,
                    AppColors.accentDark),
              if (primaVolta > 0)
                _pastiglia('$primaVolta alla prima volta', AppColors.cardLight,
                    AppColors.textSecondary),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _riquadroTurno(String titolo, (int, int)? dati) {
    final (coperti, tavoli) = dati ?? (0, 0);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
          color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(titolo,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 2),
        Text('$coperti',
            style: TextStyle(
                color: coperti == 0
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w300)),
        Text(tavoli == 1 ? '1 tavolo' : '$tavoli tavoli',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ]),
    );
  }

  Widget _pastiglia(String testo, Color sfondo, Color tinta) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: sfondo, borderRadius: BorderRadius.circular(999)),
        child: Text(testo,
            style: TextStyle(
                color: tinta, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Le cose in sospeso, in un posto solo.
class _DaFareCard extends StatelessWidget {
  final int daApprovare, senzaTavolo, messaggi;
  const _DaFareCard({
    required this.daApprovare,
    required this.senzaTavolo,
    required this.messaggi,
  });

  @override
  Widget build(BuildContext context) {
    final voci = <(IconData, String, int, Color, String)>[
      // Filtri che attraversano i giorni, non periodi: chi guarda "senza
      // tavolo" vuole tutte quelle senza tavolo, non quelle di oggi.
      (Icons.help_outline, 'Prenotazioni da approvare', daApprovare,
          AppColors.accent, '/bookings?filter=da_approvare'),
      (Icons.table_restaurant_outlined, 'Senza tavolo assegnato', senzaTavolo,
          AppColors.goldDark, '/bookings?filter=senza_tavolo'),
      (Icons.chat_bubble_outline, 'Messaggi dei clienti, ultimi 7 giorni',
          messaggi, AppColors.textSecondary, '/bookings?periodo=arrivate7'),
    ].where((v) => v.$3 > 0).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
            AppColors.gold.withValues(alpha: 0.13), AppColors.card),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.gold.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.goldDark,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.checklist_outlined,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Da fare',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(voci.length == 1 ? '1 cosa' : '${voci.length} cose',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        for (final v in voci)
          InkWell(
            onTap: () => context.go(v.$5),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Icon(v.$1, size: 18, color: v.$4),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(v.$2,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                ),
                Text('${v.$3}',
                    style: TextStyle(
                        color: v.$4,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 18),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// I prossimi sette giorni in una riga di barrette.
///
/// Serve a vedere la serata pesante prima che arrivi, e a decidere se
/// chiudere le prenotazioni online su un giorno che si sta riempiendo.
class _SettimanaCard extends StatelessWidget {
  final List<(DateTime, int)> giorni;
  final bool loading;
  final void Function(DateTime) onGiorno;

  const _SettimanaCard({
    required this.giorni,
    required this.loading,
    required this.onGiorno,
  });

  @override
  Widget build(BuildContext context) {
    final massimo = giorni.fold<int>(0, (m, g) => g.$2 > m ? g.$2 : m);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.statoAlTavolo,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.bar_chart_outlined,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('La settimana',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('coperti per giorno',
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ),
        ]),
        const SizedBox(height: 16),
        if (loading)
          const SizedBox(
              height: 90,
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent)))
        else
          SizedBox(
            height: 116,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final g in giorni) ...[
                  Expanded(child: _colonna(g.$1, g.$2, massimo)),
                  if (g != giorni.last) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
      ]),
    );
  }

  Widget _colonna(DateTime giorno, int coperti, int massimo) {
    // Le barrette sono in proporzione al giorno piu' pieno, non a una scala
    // fissa: con pochi coperti una scala assoluta le farebbe sparire tutte.
    //
    // L'altezza e' una frazione dello spazio che avanza, non un numero di
    // punti: sommando a mano numero, barra, giorno e data si sforava di
    // sedici pixel, e la scheda mostrava la fascia gialla dell'errore.
    final frazione = coperti == 0
        ? 0.05
        : (massimo == 0 ? 0.12 : (coperti / massimo).clamp(0.12, 1.0));
    final oggi = giorno.day == DateTime.now().day &&
        giorno.month == DateTime.now().month;

    return InkWell(
      onTap: () => onGiorno(giorno),
      borderRadius: BorderRadius.circular(8),
      child: Column(children: [
        Text(coperti == 0 ? '·' : '$coperti',
            style: TextStyle(
                color: coperti == 0
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: frazione,
              child: Container(
                decoration: BoxDecoration(
                  color: coperti == 0
                      ? AppColors.divider
                      : (oggi ? AppColors.accent : AppColors.gold),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(DateFormat('E', 'it_IT').format(giorno),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
                color: oggi ? AppColors.accent : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: oggi ? FontWeight.bold : FontWeight.normal)),
        Text('${giorno.day}',
            maxLines: 1,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
      ]),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutButton({required this.icon, required this.label, required this.onTap});

  /// Riquadro compatto, non piu' una riga a tutta pagina.
  ///
  /// Cinque righe alte 56 punti mangiavano mezza schermata prima di arrivare
  /// ai numeri. Affiancate tre per riga, le stesse scorciatoie stanno in due
  /// righe e il pannello si vede quasi tutto senza scorrere. Sparisce la
  /// freccia: in un riquadro cliccabile per intero non serviva.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String label;
  final String date;
  final int prenotazioni;
  final int ospiti;
  final bool loading;
  final VoidCallback? onTap;

  /// Colore e icona del riquadro: servono a distinguerlo dagli altri senza
  /// leggerne il titolo. Non sono una scala — non vogliono dire "piu'" o
  /// "meno" — ma l'identita' fissa di quel riquadro.
  final Color tinta;
  final IconData icona;

  const _StatsCard({
    required this.label,
    required this.date,
    required this.prenotazioni,
    required this.ospiti,
    required this.tinta,
    required this.icona,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Il colore serve a riconoscere il riquadro senza leggerne il titolo:
    // resta sul bordo, sull'icona e su un velo di fondo. I numeri restano
    // color inchiostro, perche' sono la cosa che si deve leggere meglio.
    // Al 5% il velo non si vedeva: sembrava che il colore non ci fosse.
    final velo = Color.alphaBlend(tinta.withValues(alpha: 0.13), AppColors.card);

    final scheda = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: velo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tinta.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tinta,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icona, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(date,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ),
              // Una freccia dice che si puo' aprire: senza, il riquadro sembra
              // solo un cartello.
              if (onTap != null)
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(children: [
                  loading
                    ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)))
                    : Text('$prenotazioni', style: const TextStyle(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.w300)),
                  const Text('Prenotazioni', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
              Container(width: 1, height: 50, color: AppColors.divider),
              Expanded(
                child: Column(children: [
                  loading
                    ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)))
                    : Text('$ospiti', style: const TextStyle(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.w300)),
                  const Text('Ospiti', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return scheda;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: scheda,
    );
  }
}

class _DaAssegnareCard extends StatelessWidget {
  final int count;
  final bool loading;
  const _DaAssegnareCard({required this.count, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: count > 0 ? AppColors.accent : AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: count > 0 ? AppColors.accentLight : AppColors.cardLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.assignment_outlined, color: count > 0 ? AppColors.accent : AppColors.textSecondary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Da assegnare', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Prenotazioni web senza tavolo', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ])),
        if (loading)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
        else
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$count', style: TextStyle(color: count > 0 ? AppColors.accent : AppColors.textSecondary, fontSize: 28, fontWeight: FontWeight.bold)),
            Text(count == 1 ? 'prenotazione' : 'prenotazioni', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
      ]),
    );
  }
}
