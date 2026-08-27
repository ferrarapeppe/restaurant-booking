import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/azioni_barra.dart';
import 'package:restaurant_booking/shared/widgets/contenuto_centrato.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';
import 'package:restaurant_booking/features/bookings/stato_giornata.dart';
import 'package:restaurant_booking/features/bookings/bookings_screen.dart'
    show BookingDetailSheet;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/widgets/pulsante_barra.dart';

// Provider per il mese focalizzato
final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime(DateTime.now().year, DateTime.now().month));

// Aperture e chiusure, per colorare il mese e per aprire/chiudere una giornata.
final regoleGiornateProvider =
    FutureProvider.autoDispose<RegoleGiornate>((ref) async => RegoleGiornate.carica());

const _idRistorante = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

enum VistaCalendario { mese, settimana, giorno }

/// Si apre sulla settimana: è il taglio con cui si lavora davvero — abbastanza
/// vicino da vedere i nomi, abbastanza largo da preparare i giorni che
/// arrivano. Il mese resta a un tocco per la visione d'insieme.
final vistaCalendarioProvider =
    StateProvider<VistaCalendario>((ref) => VistaCalendario.settimana);

/// Il lunedì della settimana in cui cade una data.
DateTime inizioSettimana(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Le prenotazioni di un intervallo di date, coi nomi.
///
/// Serve a settimana e giorno, che non mostrano solo quanti sono ma chi
/// viene: un conteggio non basta a preparare il servizio. Il mese continua
/// a usare i soli conteggi, che su trenta giorni sono molto più leggeri.
final prenotazioniIntervalloProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (String, String)>((ref, periodo) async {
  final res = await Supabase.instance.client
      .from('bookings')
      .select('id, date, time_start, party_size, status, source, notes, '
          'internal_notes, table_id, guest_id, '
          'guests(id, first_name, surname, name, phone, email), '
          'tables(id, name, capacity, area_id, areas(name))')
      .eq('restaurant_id', _idRistorante)
      .gte('date', periodo.$1)
      .lte('date', periodo.$2)
      .order('date')
      .order('time_start');
  return [for (final r in res as List) Map<String, dynamic>.from(r as Map)];
});

/// Quanti posti ha il locale in tutto, sommando la capienza dei tavoli attivi.
///
/// Serve a dire quanto è piena una serata. Se i tavoli non hanno ancora una
/// capienza sensata il totale viene basso o zero: in quel caso il calendario
/// non colora niente, invece di dare per pieno un giorno con due persone.
final postiTotaliProvider = FutureProvider<int>((ref) async {
  final res = await Supabase.instance.client
      .from('tables')
      .select('capacity, is_active')
      .eq('restaurant_id', '2b126a92-24d5-4e83-b38c-dfc82035a0cf');
  var somma = 0;
  for (final t in res as List) {
    if (t['is_active'] == false) continue;
    somma += (t['capacity'] as int?) ?? 0;
  }
  return somma;
});

// Provider per i conteggi del mese
final monthBookingCountsProvider = FutureProvider.autoDispose<Map<String, Map<String, int>>>((ref) async {
  final month = ref.watch(focusedMonthProvider);
  final result = await ref.read(bookingRepositoryProvider).getBookingCountsByMonth(month.year, month.month);
  return result;
});

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: const PulsanteBarra(),
        title: const Text('Calendario', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        actions: [
          ...azioniBarra(context),
        ],
      ),
      body: const ContenutoCentrato(
        larghezzaMassima: 1100,
        child: CalendarBody(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => context.push('/bookings/new'),
      ),
    );
  }
}

class CalendarBody extends ConsumerStatefulWidget {
  const CalendarBody();
  @override
  ConsumerState<CalendarBody> createState() => CalendarBodyState();
}

class CalendarBodyState extends ConsumerState<CalendarBody> {
  /// Scheda della giornata: stato delle prenotazioni online, comando per
  /// chiuderla o riaprirla, e accesso all'elenco del giorno.
  Future<void> _apriSchedaGiorno(DateTime giorno, RegoleGiornate regole) async {
    final esito = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SchedaGiorno(
        giorno: giorno,
        regole: regole,
        onElenco: () {
          Navigator.of(context).pop();
          final iso = DateFormat('yyyy-MM-dd').format(giorno);
          // Dal calendario si va all'elenco, non al piano sala: chi apre un
          // giorno vuole vedere chi viene, non dove sono seduti.
          context.push('/bookings?date=$iso');
        },
      ),
    );
    if (esito == true) ref.invalidate(regoleGiornateProvider);
  }

  /// Il titolo cambia col taglio: il mese, l'intervallo della settimana,
  /// la data per esteso del giorno.
  String _titolo(VistaCalendario vista, DateTime mese, DateTime giorno) {
    switch (vista) {
      case VistaCalendario.mese:
        final n = DateFormat('MMMM', 'it_IT').format(mese);
        return '${n[0].toUpperCase()}${n.substring(1)} ${mese.year}';
      case VistaCalendario.settimana:
        final da = inizioSettimana(giorno);
        final a = da.add(const Duration(days: 6));
        // "24 – 30 agosto" se restano nello stesso mese, altrimenti si
        // ripete anche il mese di partenza.
        final stessoMese = da.month == a.month;
        final primo = stessoMese
            ? '${da.day}'
            : DateFormat('d MMM', 'it_IT').format(da);
        return '$primo – ${DateFormat('d MMMM y', 'it_IT').format(a)}';
      case VistaCalendario.giorno:
        final t = DateFormat('EEEE d MMMM y', 'it_IT').format(giorno);
        return '${t[0].toUpperCase()}${t.substring(1)}';
    }
  }

  /// Le frecce si muovono di quanto vale la vista: un mese, una settimana,
  /// un giorno. Muovere sempre di un mese sarebbe inutile in vista giorno.
  void _scorri(int verso) {
    final vista = ref.read(vistaCalendarioProvider);
    final mese = ref.read(focusedMonthProvider);
    final giorno = ref.read(selectedDateProvider);
    switch (vista) {
      case VistaCalendario.mese:
        ref.read(focusedMonthProvider.notifier).state =
            DateTime(mese.year, mese.month + verso);
      case VistaCalendario.settimana:
      case VistaCalendario.giorno:
        final passo = vista == VistaCalendario.settimana ? 7 : 1;
        final nuovo =
            DateTime(giorno.year, giorno.month, giorno.day + passo * verso);
        ref.read(selectedDateProvider.notifier).state = nuovo;
        // Il mese in evidenza segue, altrimenti tornando alla vista mese ci
        // si ritrova in un mese diverso da quello che si stava guardando.
        ref.read(focusedMonthProvider.notifier).state =
            DateTime(nuovo.year, nuovo.month);
    }
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday - 1;
    final days = <DateTime>[];
    for (int i = 0; i < startWeekday; i++) days.add(firstDay.subtract(Duration(days: startWeekday - i)));
    for (int i = 0; i < lastDay.day; i++) days.add(DateTime(month.year, month.month, i + 1));
    final remaining = 7 - (days.length % 7);
    if (remaining < 7) for (int i = 1; i <= remaining; i++) days.add(lastDay.add(Duration(days: i)));
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDay = ref.watch(selectedDateProvider);
    final regole = ref.watch(regoleGiornateProvider).value;
    final postiTotali = ref.watch(postiTotaliProvider).value ?? 0;
    final days = _getDaysInMonth(focusedMonth);

    final vista = ref.watch(vistaCalendarioProvider);

    return Column(children: [
      // Testata: frecce, titolo che cambia con la vista, e il selettore.
      // Sul fondo pagina, così il riquadro sotto stacca.
      Container(
        color: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => _scorri(-1),
          ),
          Expanded(child: Text(_titolo(vista, focusedMonth, selectedDay),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold))),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            onPressed: () => _scorri(1),
          ),
          IconButton(
            tooltip: 'Torna a oggi',
            icon: const Icon(Icons.today, color: AppColors.textSecondary, size: 20),
            onPressed: () {
              final ora = DateTime.now();
              ref.read(focusedMonthProvider.notifier).state =
                  DateTime(ora.year, ora.month);
              ref.read(selectedDateProvider.notifier).state =
                  DateTime(ora.year, ora.month, ora.day);
            },
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Row(children: [
          for (final v in VistaCalendario.values) ...[
            _BottoneVista(
              etichetta: switch (v) {
                VistaCalendario.mese => 'Mese',
                VistaCalendario.settimana => 'Settimana',
                VistaCalendario.giorno => 'Giorno',
              },
              scelta: vista == v,
              onTap: () => ref.read(vistaCalendarioProvider.notifier).state = v,
            ),
            if (v != VistaCalendario.values.last) const SizedBox(width: 8),
          ],
        ]),
      ),
      if (vista == VistaCalendario.settimana)
        Expanded(child: _VistaSettimana(
          giorno: selectedDay,
          regole: regole,
          postiTotali: postiTotali,
          onGiorno: (g) {
            ref.read(selectedDateProvider.notifier).state = g;
            if (regole != null) _apriSchedaGiorno(g, regole);
          },
        ))
      else if (vista == VistaCalendario.giorno)
        Expanded(child: _VistaGiorno(
          giorno: selectedDay,
          regole: regole,
          postiTotali: postiTotali,
          onApriScheda: regole == null
              ? null
              : () => _apriSchedaGiorno(selectedDay, regole),
        ))
      else
        Expanded(
          child: _VistaMese(
            mese: focusedMonth,
            giorni: days,
            selezionato: selectedDay,
            regole: regole,
            postiTotali: postiTotali,
            onGiorno: (g) {
              ref.read(selectedDateProvider.notifier).state = g;
              if (regole != null) _apriSchedaGiorno(g, regole);
            },
          ),
        ),
    ]);
  }
}

/// Le tre pastiglie che scelgono il taglio.
class _BottoneVista extends StatelessWidget {
  final String etichetta;
  final bool scelta;
  final VoidCallback onTap;
  const _BottoneVista({
    required this.etichetta,
    required this.scelta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: scelta ? AppColors.accentLight : AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: scelta ? AppColors.accent : AppColors.divider),
          ),
          child: Text(etichetta,
              style: TextStyle(
                color: scelta ? AppColors.accent : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: scelta ? FontWeight.bold : FontWeight.normal,
              )),
        ),
      );
}

/// Colonne dei sette giorni, con dentro chi viene.
///
/// È il taglio che mancava: il mese dice quanti sono ma non chi, il giorno
/// dice tutto di una data sola. La settimana serve a preparare — vedere
/// dov'è la serata pesante mentre c'è ancora tempo per intervenire.
class _VistaSettimana extends ConsumerWidget {
  final DateTime giorno;
  final RegoleGiornate? regole;
  final int postiTotali;
  final void Function(DateTime) onGiorno;

  const _VistaSettimana({
    required this.giorno,
    required this.regole,
    required this.postiTotali,
    required this.onGiorno,
  });

  static const double _colonnaOre = 68;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final da = inizioSettimana(giorno);
    final a = da.add(const Duration(days: 6));
    final f = DateFormat('yyyy-MM-dd');
    final asincrono =
        ref.watch(prenotazioniIntervalloProvider((f.format(da), f.format(a))));
    final giorni = [
      for (var i = 0; i < 7; i++) DateTime(da.year, da.month, da.day + i)
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: asincrono.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(
            child: Text('Errore: $e',
                style: const TextStyle(color: AppColors.textSecondary))),
        data: (tutte) {
          final righe = tutte.where((b) => !statoSpento(b['status'])).toList();

          // Le righe della griglia sono solo gli orari in cui c'e' qualcuno.
          // Una scala fissa dalle 17 alle 23 sarebbe quasi tutta vuota: qui
          // si prenota su tre turni, non a ogni mezz'ora.
          final orari = righe.map(oraBreve).toSet().toList()..sort();

          final perCella = <String, List<Map<String, dynamic>>>{};
          final copertiGiorno = <String, int>{};
          for (final b in righe) {
            final d = (b['date'] ?? '').toString();
            perCella.putIfAbsent(d + '|' + oraBreve(b), () => []).add(b);
            copertiGiorno[d] =
                (copertiGiorno[d] ?? 0) + ((b['party_size'] as int?) ?? 0);
          }

          return Column(children: [
            _testata(giorni, copertiGiorno, f),
            Expanded(
              child: orari.isEmpty
                  ? const Center(
                      child: Text('Nessuna prenotazione questa settimana.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 15)),
                    )
                  : ListView.builder(
                      itemCount: orari.length,
                      itemBuilder: (_, i) => _rigaOrario(
                          context, ref, orari[i], giorni, perCella, f),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _testata(
      List<DateTime> giorni, Map<String, int> coperti, DateFormat f) {
    // `IntrinsicHeight` e' necessario: dentro una colonna la riga non ha
    // un'altezza da cui partire, e con lo stretch si schiaccia a zero
    // portandosi via l'intestazione.
    return Container(
      color: AppColors.nero,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(width: _colonnaOre),
          for (final g in giorni)
            Expanded(child: _testataGiorno(g, coperti[f.format(g)] ?? 0)),
        ]),
      ),
    );
  }

  Widget _testataGiorno(DateTime g, int coperti) {
    final stato = regole?.stato(g) ?? StatoGiornata.inCaricamento;
    final spenta = stato == StatoGiornata.chiuse ||
        stato == StatoGiornata.chiusuraSettimanale ||
        stato == StatoGiornata.nonAncoraAperte;
    final oggi = _stessoGiorno(g, DateTime.now());
    final nome = DateFormat('EEE', 'it_IT').format(g);

    // Testata scura come la barra del marchio: da' un bordo alla griglia e
    // fa risaltare le prenotazioni, che prima erano beige su beige.
    return InkWell(
      onTap: () => onGiorno(g),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        decoration: BoxDecoration(
          color: oggi ? AppColors.accent : null,
          border: const Border(
              left: BorderSide(color: Color(0x33FFFFFF), width: 0.5)),
        ),
        child: Column(children: [
          Text(nome[0].toUpperCase() + nome.substring(1),
              style: TextStyle(
                  color: oggi ? Colors.white : AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          Text('${g.day}',
              style: TextStyle(
                  color: oggi
                      ? Colors.white
                      : (spenta ? const Color(0xFF8C8078) : Colors.white),
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
              spenta
                  ? AspettoStato.di(stato).breve.toLowerCase()
                  : (coperti == 0 ? 'libero' : '$coperti coperti'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: oggi
                      ? Colors.white70
                      : (spenta ? const Color(0xFF8C8078) : AppColors.gold),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          BottoneElenco(
              giorno: g, colore: oggi ? Colors.white : AppColors.gold),
        ]),
      ),
    );
  }

  Widget _rigaOrario(BuildContext context, WidgetRef ref, String orario,
      List<DateTime> giorni,
      Map<String, List<Map<String, dynamic>>> perCella, DateFormat f) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          width: _colonnaOre,
          color: AppColors.cardLight,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.topCenter,
          child: Text(orario,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ),
        for (final g in giorni)
          Expanded(
              child: _cella(
                  context, ref, g, perCella[f.format(g) + '|' + orario])),
      ]),
    );
  }

  Widget _cella(BuildContext context, WidgetRef ref, DateTime g,
      List<Map<String, dynamic>>? righe) {
    final stato = regole?.stato(g) ?? StatoGiornata.inCaricamento;
    final spenta = stato == StatoGiornata.chiuse ||
        stato == StatoGiornata.chiusuraSettimanale ||
        stato == StatoGiornata.nonAncoraAperte;
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      decoration: BoxDecoration(
        // Le giornate chiuse restano spente, le altre bianche: cosi' le
        // pastiglie ci staccano sopra invece di annegarci.
        color: spenta ? AppColors.background : AppColors.surface,
        border: const Border(
          left: BorderSide(color: AppColors.divider, width: 0.5),
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(children: [
        for (final b in righe ?? const <Map<String, dynamic>>[])
          _pastiglia(context, ref, b),
      ]),
    );
  }

  /// La pastiglia prende il colore dallo stato, come dappertutto nell'app:
  /// oro se aspetta una risposta, verde se accettata, blu se gia' al tavolo.
  Widget _pastiglia(
      BuildContext context, WidgetRef ref, Map<String, dynamic> b) {
    final (tinta, sfondo) = coloriStato(b['status']);
    return InkWell(
      onTap: () => apriDettaglio(context, ref, b),
      borderRadius: BorderRadius.circular(7),
      child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(7, 5, 6, 6),
      decoration: BoxDecoration(
        color: sfondo,
        borderRadius: BorderRadius.circular(7),
        border: Border(left: BorderSide(color: tinta, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nomeBreve(b['guests'] as Map?),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        Row(children: [
          Icon(Icons.people_outline, size: 12, color: tinta),
          const SizedBox(width: 3),
          Text('${b['party_size'] ?? 0}',
              style: TextStyle(
                  color: tinta, fontSize: 12, fontWeight: FontWeight.w600)),
          if ((b['tables'] as Map?)?['name'] != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.table_restaurant_outlined,
                size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 2),
            Flexible(
              child: Text('${(b['tables'] as Map)['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ),
          ],
        ]),
      ]),
      ),
    );
  }
}

/// Il colore di una prenotazione viene dal suo stato, come dappertutto
/// nell'app: oro se aspetta risposta, verde se accettata, blu se al tavolo.
(Color, Color) coloriStato(dynamic stato) => switch (stato) {
      'pending' => (AppColors.gold, AppColors.goldLight),
      'seated' => (AppColors.statoAlTavolo, const Color(0xFFE9F1FA)),
      _ => (AppColors.statoConfermato, AppColors.statoConfermatoSfondo),
    };

/// Apre l'elenco delle prenotazioni di una giornata.
///
/// Il pulsante c'e' in tutte e tre le viste, sempre con la stessa icona:
/// prima l'elenco si raggiungeva solo toccando la cella, e un comando che
/// non si vede e' come se non ci fosse.
void apriElencoDelGiorno(BuildContext context, DateTime giorno) {
  context.push('/bookings?date=${DateFormat('yyyy-MM-dd').format(giorno)}');
}

/// Il pulsantino dell'elenco, uguale nelle tre viste.
class BottoneElenco extends StatelessWidget {
  final DateTime giorno;
  final Color colore;
  final double misura;
  const BottoneElenco({
    super.key,
    required this.giorno,
    required this.colore,
    this.misura = 16,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => apriElencoDelGiorno(context, giorno),
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: 'Apri l\'elenco del giorno',
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(Icons.list_alt_outlined, size: misura, color: colore),
          ),
        ),
      );
}

/// Apre la scheda della prenotazione.
///
/// E' la stessa dell'elenco, non una copia: modificare da qui o da la' deve
/// avere esattamente lo stesso effetto, mail comprese.
Future<void> apriDettaglio(
    BuildContext context, WidgetRef ref, Map<String, dynamic> b) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => BookingDetailSheet(
      booking: b,
      onSaved: () {
        Navigator.pop(context);
        ref.invalidate(prenotazioniIntervalloProvider);
        ref.invalidate(monthBookingCountsProvider);
      },
    ),
  );
}

/// "20:00:00" -> "20:00". Gli orari sono le righe della griglia, quindi
/// devono coincidere esattamente fra prenotazioni diverse.
String oraBreve(Map b) {
  final t = (b['time_start'] ?? '').toString();
  return t.length >= 5 ? t.substring(0, 5) : t;
}

bool _stessoGiorno(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Le prenotazioni annullate non si mostrano nel calendario.
bool statoSpento(dynamic stato) =>
    stato == 'canceled' || stato == 'rejected' || stato == 'no_show';

String nomeBreve(Map? guests) {
  if (guests == null) return 'senza scheda';
  final unito = [
    (guests['first_name'] ?? '').toString().trim(),
    (guests['surname'] ?? '').toString().trim(),
  ].where((s) => s.isNotEmpty).join(' ');
  if (unito.isNotEmpty) return unito;
  final n = (guests['name'] ?? '').toString().trim();
  return n.isEmpty ? 'senza nome' : n;
}

/// Una giornata sola, in ordine di orario e divisa per turno.
///
/// Non rifà l'elenco né il piano sala: è l'agenda della serata, quello che
/// si guarda prima del servizio per sapere come si presenta.
class _VistaGiorno extends ConsumerWidget {
  final DateTime giorno;
  final RegoleGiornate? regole;
  final int postiTotali;
  final VoidCallback? onApriScheda;

  const _VistaGiorno({
    required this.giorno,
    required this.regole,
    required this.postiTotali,
    required this.onApriScheda,
  });

  static const double _colonnaOre = 68;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iso = DateFormat('yyyy-MM-dd').format(giorno);
    final asincrono = ref.watch(prenotazioniIntervalloProvider((iso, iso)));
    final stato = regole?.stato(giorno) ?? StatoGiornata.inCaricamento;
    final spenta = stato == StatoGiornata.chiuse ||
        stato == StatoGiornata.chiusuraSettimanale ||
        stato == StatoGiornata.nonAncoraAperte;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: asincrono.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(
            child: Text('Errore: $e',
                style: const TextStyle(color: AppColors.textSecondary))),
        data: (tutte) {
          final righe = tutte.where((b) => !statoSpento(b['status'])).toList();
          final coperti =
              righe.fold<int>(0, (s, r) => s + ((r['party_size'] as int?) ?? 0));
          final orari = righe.map(oraBreve).toSet().toList()..sort();

          final perOrario = <String, List<Map<String, dynamic>>>{};
          for (final b in righe) {
            perOrario.putIfAbsent(oraBreve(b), () => []).add(b);
          }

          return Column(children: [
            // Testata scura come nella settimana: le tre viste devono
            // sembrare la stessa schermata con tre tagli diversi.
            Container(
              width: double.infinity,
              color: AppColors.nero,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Text(DateFormat('EEEE', 'it_IT')
                    .format(giorno)
                    .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase()),
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('${giorno.day}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 14),
                if (spenta)
                  Text(AspettoStato.di(stato).breve.toLowerCase(),
                      style: const TextStyle(
                          color: Color(0xFF8C8078), fontSize: 13)),
                const Spacer(),
                Text(
                    postiTotali > 0
                        ? '$coperti su $postiTotali coperti'
                        : '$coperti coperti',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(width: 12),
                BottoneElenco(
                    giorno: giorno, colore: AppColors.gold, misura: 20),
                if (onApriScheda != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Apri o chiudi le prenotazioni online',
                    icon: const Icon(Icons.tune, color: AppColors.gold, size: 20),
                    onPressed: onApriScheda,
                  ),
                ],
              ]),
            ),
            Expanded(
              child: orari.isEmpty
                  ? const Center(
                      child: Text('Nessuna prenotazione per questa giornata.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 15)),
                    )
                  : ListView.builder(
                      itemCount: orari.length,
                      itemBuilder: (_, i) => _rigaOrario(
                          context, ref, orari[i], perOrario[orari[i]]!),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _rigaOrario(BuildContext context, WidgetRef ref, String orario,
      List<Map<String, dynamic>> righe) {
    final coperti =
        righe.fold<int>(0, (s, r) => s + ((r['party_size'] as int?) ?? 0));
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          width: _colonnaOre,
          color: AppColors.cardLight,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(children: [
            Text(orario,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text('$coperti p.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                left: BorderSide(color: AppColors.divider, width: 0.5),
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              for (final b in righe) _riga(context, ref, b),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _riga(BuildContext context, WidgetRef ref, Map<String, dynamic> b) {
    final (tinta, sfondo) = coloriStato(b['status']);
    final tavolo = (b['tables'] as Map?)?['name'];
    final note = (b['notes'] ?? '').toString().trim();

    return InkWell(
      onTap: () => apriDettaglio(context, ref, b),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: sfondo,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: tinta, width: 4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(nomeBreve(b['guests'] as Map?),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
            Icon(Icons.people_outline, size: 15, color: tinta),
            const SizedBox(width: 4),
            Text('${b['party_size'] ?? 0}',
                style: TextStyle(
                    color: tinta, fontSize: 14, fontWeight: FontWeight.bold)),
            if (tavolo != null) ...[
              const SizedBox(width: 12),
              const Icon(Icons.table_restaurant_outlined,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text('$tavolo',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
            if (b['status'] == 'pending') ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('da approvare',
                    style: TextStyle(
                        color: AppColors.nero,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ]),
      ),
    );
  }
}

/// Scheda della giornata: dice se il modulo online accetta prenotazioni e
/// permette di chiuderla o riaprirla senza passare dalle impostazioni.
class _SchedaGiorno extends StatefulWidget {
  final DateTime giorno;
  final RegoleGiornate regole;
  final VoidCallback onElenco;
  const _SchedaGiorno({required this.giorno, required this.regole, required this.onElenco});

  @override
  State<_SchedaGiorno> createState() => _SchedaGiornoState();
}

class _SchedaGiornoState extends State<_SchedaGiorno> {
  bool _inCorso = false;

  Future<void> _cambia(StatoGiornata stato) async {
    setState(() => _inCorso = true);
    String? motivo;
    try {
      if (stato == StatoGiornata.aperte) {
        motivo = await RegoleGiornate.chiudi(widget.giorno);
      } else {
        final id = widget.regole.idBlocco(widget.giorno);
        motivo = id == null ? 'blocco non trovato' : await RegoleGiornate.riapri(id);
      }
    } catch (e) {
      motivo = '$e';
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(motivo == null);
    messenger.showSnackBar(SnackBar(
      content: Text(motivo == null
          ? (stato == StatoGiornata.aperte
              ? 'Prenotazioni online chiuse per questa giornata.'
              : 'Prenotazioni online riaperte.')
          : 'Non riuscito: $motivo.'),
      backgroundColor: AppColors.accent,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final stato = widget.regole.stato(widget.giorno);
    final modificabile = stato == StatoGiornata.aperte || stato == StatoGiornata.chiuse;
    final chiusa = stato == StatoGiornata.chiuse;
    final titolo = DateFormat('EEEE d MMMM yyyy', 'it_IT').format(widget.giorno);

    final spiegazione = switch (stato) {
      StatoGiornata.aperte =>
        'Il modulo online accetta prenotazioni per questa data.',
      StatoGiornata.chiuse =>
        'Il modulo online non accetta prenotazioni per questa data. '
            "Voi potete comunque inserirle dall'app.",
      StatoGiornata.chiusuraSettimanale =>
        'È il giorno di chiusura settimanale. Si cambia da Impostazioni → Orari di apertura.',
      _ => widget.regole.motivoNonAperta(widget.giorno),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          Text(titolo[0].toUpperCase() + titolo.substring(1),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: chiusa ? AppColors.accentLight
                  : stato == StatoGiornata.aperte ? AppColors.statoConfermatoSfondo : AppColors.cardLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(AspettoStato.di(stato).etichetta, style: TextStyle(
              color: chiusa ? AppColors.accent
                  : stato == StatoGiornata.aperte ? AppColors.statoConfermato : AppColors.textSecondary,
              fontSize: 12, fontWeight: FontWeight.bold,
            )),
          ),
          const SizedBox(height: 12),
          Text(spiegazione, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: chiusa ? AppColors.statoConfermato : AppColors.accent,
                disabledBackgroundColor: AppColors.cardLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: modificabile && !_inCorso ? () => _cambia(stato) : null,
              icon: _inCorso
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(chiusa ? Icons.lock_open_outlined : Icons.lock_outline, size: 18),
              label: Text(chiusa ? 'Riapri le prenotazioni online' : 'Chiudi le prenotazioni online'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: widget.onElenco,
              icon: const Icon(Icons.list_alt_outlined, size: 18),
              label: const Text('Apri l\'elenco del giorno'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Il mese, con la stessa lingua della settimana: celle bianche, pastiglie
/// colorate dallo stato, giornate chiuse spente.
///
/// Prima mostrava solo dei conteggi su fondo dorato. Funzionava finche' i
/// numeri erano l'unica cosa da sapere, ma accanto alla settimana sembrava
/// un'altra applicazione — e la scritta "non aperte" ripetuta trenta volte
/// tingeva di spento la griglia intera per dire una cosa sola.
class _VistaMese extends ConsumerWidget {
  final DateTime mese;
  final List<DateTime> giorni;
  final DateTime selezionato;
  final RegoleGiornate? regole;
  final int postiTotali;
  final void Function(DateTime) onGiorno;

  const _VistaMese({
    required this.mese,
    required this.giorni,
    required this.selezionato,
    required this.regole,
    required this.postiTotali,
    required this.onGiorno,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = DateFormat('yyyy-MM-dd');
    final asincrono = ref.watch(prenotazioniIntervalloProvider(
        (f.format(giorni.first), f.format(giorni.last))));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          color: AppColors.nero,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
              children: ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList()),
        ),
        Expanded(
          child: asincrono.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent)),
            error: (e, _) => Center(
                child: Text('Errore: $e',
                    style: const TextStyle(color: AppColors.textSecondary))),
            data: (tutte) {
              final perGiorno = <String, List<Map<String, dynamic>>>{};
              for (final b in tutte) {
                if (statoSpento(b['status'])) continue;
                perGiorno
                    .putIfAbsent((b['date'] ?? '').toString(), () => [])
                    .add(b);
              }
              return GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7, childAspectRatio: 0.78),
                itemCount: giorni.length,
                itemBuilder: (context, i) {
                  final g = giorni[i];
                  return _CellaMese(
                    giorno: g,
                    delMese: g.month == mese.month,
                    selezionato: _stessoGiorno(g, selezionato),
                    righe: perGiorno[f.format(g)] ?? const [],
                    postiTotali: postiTotali,
                    stato: regole?.stato(g) ?? StatoGiornata.inCaricamento,
                    onGiorno: onGiorno,
                    onPrenotazione: (b) => apriDettaglio(context, ref, b),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _CellaMese extends StatelessWidget {
  final DateTime giorno;
  final bool delMese, selezionato;
  final List<Map<String, dynamic>> righe;
  final int postiTotali;
  final StatoGiornata stato;
  final void Function(DateTime) onGiorno;
  final void Function(Map<String, dynamic>) onPrenotazione;

  const _CellaMese({
    required this.giorno,
    required this.delMese,
    required this.selezionato,
    required this.righe,
    required this.postiTotali,
    required this.stato,
    required this.onGiorno,
    required this.onPrenotazione,
  });

  bool get _oggi => _stessoGiorno(giorno, DateTime.now());

  /// Solo le chiusure vere spengono la cella.
  ///
  /// "Non ancora aperte" riguarda tutte le date prima del 1 settembre: se
  /// spegnesse anche quelle, il mese intero sarebbe grigio per dire una cosa
  /// che si legge una volta sola.
  bool get _chiusa =>
      stato == StatoGiornata.chiuse ||
      stato == StatoGiornata.chiusuraSettimanale;

  @override
  Widget build(BuildContext context) {
    final coperti =
        righe.fold<int>(0, (s, r) => s + ((r['party_size'] as int?) ?? 0));
    final quota = postiTotali > 0 ? (coperti / postiTotali).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: delMese ? () => onGiorno(giorno) : null,
      child: Container(
        decoration: BoxDecoration(
          color: !delMese
              ? AppColors.background
              : _chiusa
                  ? AppColors.background
                  : AppColors.surface,
          border: Border(
            right: const BorderSide(color: AppColors.divider, width: 0.5),
            bottom: const BorderSide(color: AppColors.divider, width: 0.5),
            top: BorderSide(
                color: selezionato && delMese
                    ? AppColors.accent
                    : Colors.transparent,
                width: 2),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Quanto e' piena la serata, in una riga sola in cima: dice il
          // livello senza tingere la cella e senza litigare con le pastiglie.
          SizedBox(
            height: 4,
            child: Row(children: [
              if (quota > 0) Expanded(flex: (quota * 100).round(), child: Container(color: AppColors.gold)),
              Expanded(flex: (100 - quota * 100).round(), child: const SizedBox()),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 4, 7, 2),
            child: Row(children: [
              Text('${giorno.day}',
                  style: TextStyle(
                    color: !delMese
                        ? AppColors.textMuted
                        : _oggi
                            ? AppColors.accent
                            : _chiusa
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: _oggi ? FontWeight.bold : FontWeight.w600,
                  )),
              const Spacer(),
              if (delMese && coperti > 0) ...[
                Text('$coperti',
                    style: const TextStyle(
                        color: AppColors.goldDark,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
              ],
              if (delMese)
                BottoneElenco(
                    giorno: giorno,
                    colore: AppColors.textMuted,
                    misura: 14),
            ]),
          ),
          if (delMese && _chiusa)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Text(AspettoStato.di(stato).breve.toLowerCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ),
          if (delMese)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final b in righe.take(3)) _pastiglia(b),
                  if (righe.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 3, top: 1),
                      child: Text('+${righe.length - 3} altre',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  Widget _pastiglia(Map<String, dynamic> b) {
    final (tinta, sfondo) = coloriStato(b['status']);
    return GestureDetector(
      onTap: () => onPrenotazione(b),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: sfondo,
          borderRadius: BorderRadius.circular(5),
          border: Border(left: BorderSide(color: tinta, width: 3)),
        ),
        child: Row(children: [
          Text(oraBreve(b),
              style: TextStyle(
                  color: tinta, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(nomeBreve(b['guests'] as Map?),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 11)),
          ),
        ]),
      ),
    );
  }
}
