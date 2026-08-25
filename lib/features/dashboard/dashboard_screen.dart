import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';

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
  int _daAssegnare = 0;
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

      // Query prossimi 7 giorni
      final settimanaRes = await supabase
          .from('bookings')
          .select('party_size')
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

      // Query da assegnare (web, senza tavolo)
      final daAssegnareRes = await supabase
          .from('bookings')
          .select('id')
          .eq('restaurant_id', _restaurantId)
          .eq('source', 'web')
          .eq('status', 'pending');

      int sommaOspiti(List<dynamic> righe) {
        var totale = 0;
        for (final r in righe) {
          totale += ((r as Map)['party_size'] as int? ?? 0);
        }
        return totale;
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
        _daAssegnare = daAssegnareRes.length;
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
        // Il logo intero non entra nei 56 punti standard di una barra.
        toolbarHeight: stretto ? 68 : 84,
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
        title: Image.asset(
          'assets/images/logo_splash.png',
          height: stretto ? 46 : 56,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white70),
              onPressed: () {}),
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
              const Text('Scorciatoie', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _ShortcutButton(icon: Icons.calendar_today_outlined, label: 'Prenotazioni oggi', onTap: () {
                  final today = DateTime.now();
                  final dateStr = DateFormat('yyyy-MM-dd').format(today);
                  ref.read(selectedDateProvider.notifier).state = today;
                  context.go('/bookings?date=' + dateStr);
                }),
              const SizedBox(height: 8),
              _ShortcutButton(icon: Icons.calendar_month_outlined, label: 'Prenotazioni questo mese', onTap: () => context.go('/calendar')),
              const SizedBox(height: 8),
              _ShortcutButton(icon: Icons.settings_outlined, label: 'Impostazioni e componenti aggiuntivi', onTap: () => context.go('/settings')),
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
                  date: '$oggi - $tra7',
                  prenotazioni: _settimanaPrenotazioni,
                  ospiti: _settimanaOspiti,
                  loading: _loading,
                  onTap: () => context.go('/bookings?periodo=settimana'),
                ),
                _StatsCard(
                  label: 'Questo mese',
                  date: mese,
                  prenotazioni: _mesePrenotazioni,
                  ospiti: _meseOspiti,
                  loading: _loading,
                  onTap: () => context.go('/bookings?periodo=mese'),
                ),
                _StatsCard(
                  label: 'Totale ${DateTime.now().year}',
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

class _ShortcutButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
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
  const _StatsCard({
    required this.label,
    required this.date,
    required this.prenotazioni,
    required this.ospiti,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheda = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
