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
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider per il mese focalizzato
final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime(DateTime.now().year, DateTime.now().month));

// Aperture e chiusure, per colorare il mese e per aprire/chiudere una giornata.
final regoleGiornateProvider =
    FutureProvider.autoDispose<RegoleGiornate>((ref) async => RegoleGiornate.carica());

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
        leading: Builder(builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        )),
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
  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

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
    final countsAsync = ref.watch(monthBookingCountsProvider);
    final regole = ref.watch(regoleGiornateProvider).value;
    final postiTotali = ref.watch(postiTotaliProvider).value ?? 0;
    final days = _getDaysInMonth(focusedMonth);
    final monthName = DateFormat('MMMM', 'it_IT').format(focusedMonth);
    final capitalMonth = monthName[0].toUpperCase() + monthName.substring(1);

    return Column(children: [
      // Header mese, sul fondo pagina: cosi' il riquadro della griglia
      // stacca, come i box del pannello di controllo.
      Container(
        color: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => ref.read(focusedMonthProvider.notifier).state = DateTime(focusedMonth.year, focusedMonth.month - 1),
          ),
          Expanded(child: Text('$capitalMonth ${focusedMonth.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold))),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            onPressed: () => ref.read(focusedMonthProvider.notifier).state = DateTime(focusedMonth.year, focusedMonth.month + 1),
          ),
          IconButton(
            icon: const Icon(Icons.today, color: AppColors.textSecondary, size: 20),
            onPressed: () => ref.read(focusedMonthProvider.notifier).state = DateTime(DateTime.now().year, DateTime.now().month),
          ),
        ]),
      ),
      // Il riquadro del mese: intestazione dei giorni e griglia dentro lo
      // stesso box, staccato dal fondo tortora.
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
      Container(
        color: AppColors.cardLight,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: ['Lun','Mar','Mer','Gio','Ven','Sab','Dom'].map((d) => Expanded(
          child: Center(child: Text(d, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600))),
        )).toList()),
      ),
      const Divider(height: 1, color: AppColors.divider),
      // Griglia
      Expanded(
        child: countsAsync.when(
          loading: () => GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.52),
            itemCount: days.length,
            itemBuilder: (_, i) => _DayCell(day: days[i], focusedMonth: focusedMonth, isSelected: _isSameDay(days[i], selectedDay), counts: null, stato: StatoGiornata.inCaricamento, postiTotali: postiTotali),
          ),
          error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppColors.textSecondary))),
          data: (counts) => GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.52),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final key = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
              final dayData = counts[key];
              final delMese = day.month == focusedMonth.month;
              return GestureDetector(
                onTap: () {
                  if (!delMese) return;
                  ref.read(selectedDateProvider.notifier).state = day;
                  if (regole == null) return; // stato non ancora noto
                  _apriSchedaGiorno(day, regole);
                },
                child: _DayCell(
                  day: day,
                  focusedMonth: focusedMonth,
                  isSelected: _isSameDay(day, selectedDay),
                  counts: dayData,
                  postiTotali: postiTotali,
                  stato: delMese && regole != null
                      ? regole.stato(day)
                      : StatoGiornata.inCaricamento,
                ),
              );
            },
          ),
        ),
      ),
          ]),
        ),
      ),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day, focusedMonth;
  final bool isSelected;
  final StatoGiornata stato;
  final Map<String, int>? counts;
  final int postiTotali;
  const _DayCell({
    required this.day,
    required this.focusedMonth,
    required this.isSelected,
    required this.stato,
    required this.counts,
    required this.postiTotali,
  });

  bool get _isCurrentMonth => day.month == focusedMonth.month;
  bool get _isToday { final n = DateTime.now(); return day.year == n.year && day.month == n.month && day.day == n.day; }
  bool get _weekend => day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

  /// Una giornata in cui non si lavora: chiusura settimanale, chiusura
  /// straordinaria, oppure data ancora fuori dal periodo prenotabile.
  bool get _spenta =>
      stato == StatoGiornata.chiuse ||
      stato == StatoGiornata.chiusuraSettimanale ||
      stato == StatoGiornata.nonAncoraAperte;

  int get _coperti => counts?['ospiti'] ?? 0;
  int get _prenotazioni => counts?['prenotazioni'] ?? 0;
  int get _daApprovare => counts?['pending'] ?? 0;

  /// Da vuoto a pieno su una scala sola, l'oro del marchio.
  ///
  /// Una scala e non cinque colori diversi: cosi' il fondo si legge come una
  /// quantita' invece che come categorie da ricordare. Senza una capienza
  /// credibile non si colora niente, altrimenti due persone in un locale
  /// con i tavoli a zero risulterebbero "al completo".
  (Color, Color) get _fondoERiempimento {
    if (_spenta) return (AppColors.background, AppColors.textMuted);
    if (_coperti == 0 || postiTotali <= 0) {
      return (AppColors.surface, AppColors.textSecondary);
    }
    final quota = _coperti / postiTotali;
    if (quota < 0.25) return (const Color(0xFFFBF7EE), AppColors.goldDark);
    if (quota < 0.60) return (const Color(0xFFF1E6C9), AppColors.goldDark);
    if (quota < 0.90) return (const Color(0xFFE3D0A0), const Color(0xFF4A3D12));
    return (AppColors.gold, const Color(0xFF3D2F06));
  }

  @override
  Widget build(BuildContext context) {
    final (fondo, testo) = _fondoERiempimento;
    final pieno = postiTotali > 0 && _coperti >= postiTotali;

    return Container(
      margin: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: !_isCurrentMonth
            ? AppColors.background
            : isSelected
                ? AppColors.accentLight
                // Sabato e domenica appena piu' caldi, per dare ritmo alla
                // griglia: lo stesso trucco delle bande orarie.
                : (fondo == AppColors.surface && _weekend
                    ? AppColors.cardLight
                    : fondo),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _isToday ? AppColors.accent : AppColors.divider,
            width: _isToday ? 2 : 0.5),
      ),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 0, 2),
            child: Text('${day.day}', style: TextStyle(
              color: !_isCurrentMonth
                  ? AppColors.textMuted
                  : _isToday
                      ? AppColors.accent
                      : _spenta
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
              fontSize: 17,
              fontWeight: _isToday ? FontWeight.bold : FontWeight.w600,
            )),
          ),
          if (_isCurrentMonth) ...[
            if (_spenta)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(AspettoStato.di(stato).breve.toLowerCase(),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            // Testo semplice al posto delle pastiglie: impilate mangiavano
            // meta' cella per dire due numeri, e ora e' il fondo a farsi notare.
            if (_prenotazioni > 0) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$_prenotazioni prenotaz. · $_coperti pers.',
                    style: TextStyle(
                        color: testo, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
            if (pieno)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text('al completo',
                    style: TextStyle(color: testo, fontSize: 12)),
              ),
          ],
        ]),
        // L'unica cosa su cui si deve agire: si vede da lontano.
        if (_isCurrentMonth && _daApprovare > 0)
          Positioned(
            top: 7,
            right: 7,
            child: Tooltip(
              message: '$_daApprovare da approvare',
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle),
              ),
            ),
          ),
      ]),
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

