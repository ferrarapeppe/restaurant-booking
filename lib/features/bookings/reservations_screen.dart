import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/theme/colori_sala.dart';
import 'package:restaurant_booking/shared/widgets/azioni_barra.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';
import 'package:restaurant_booking/features/bookings/bookings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;
import 'package:restaurant_booking/shared/widgets/pulsante_barra.dart';

class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});
  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: const PulsanteBarra(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: Colors.white70),
              onPressed: () => ref.read(selectedDateProvider.notifier).state =
                  selectedDate.subtract(const Duration(days: 1)),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2027),
                );
                if (picked != null && mounted) {
                  ref.read(selectedDateProvider.notifier).state = picked;
                }
              },
              child: Text(
                DateFormat('EEE dd MMM', 'it_IT').format(selectedDate),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: Colors.white70),
              onPressed: () => ref.read(selectedDateProvider.notifier).state =
                  selectedDate.add(const Duration(days: 1)),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          ...azioniBarra(context),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: Colors.white70),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime(2027),
              );
              if (picked != null && mounted) {
                ref.read(selectedDateProvider.notifier).state = picked;
              }
            },
          ),
          Stack(
            children: [
            ],
          ),
        ],
      ),
      body: const _ScheduleBody(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleBody extends ConsumerStatefulWidget {
  const _ScheduleBody();
  @override
  ConsumerState<_ScheduleBody> createState() => _ScheduleBodyState();
}

class _ScheduleBodyState extends ConsumerState<_ScheduleBody> {
  static const _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _tables = [];
  bool _loading = false;

  static const int _startHour = 17;
  static const int _endHour = 23;
  static const int _slotMinutes = 15;
  static const double _slotWidth = 52.0;
  static const double _rowHeight = 50.0;
  // Larga abbastanza per il numero del tavolo e la sua capienza a testo
  // leggibile: a 76 il pallino dei posti schiacciava il numero.
  static const double _labelWidth = 96.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final date = ref.read(selectedDateProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final supabase = supabase_flutter.Supabase.instance.client;
      final tablesRes = await supabase
          .from('tables')
          .select('*, areas(name)')
          .eq('restaurant_id', _restaurantId)
          .order('name');
      final bookingsRes = await supabase
          .from('bookings')
          // `phone` non era nell'elenco, e la scheda che si apre da qui e'
          // modificabile: il campo telefono nasceva vuoto perche' il dato non
          // era stato caricato, e salvando cancellava il numero del cliente.
          .select('*, guests(first_name, surname, name, phone, email), tables(name, areas(name))')
          .eq('restaurant_id', _restaurantId)
          .eq('date', dateStr)
          .inFilter('status', ['approved', 'pending', 'seated', 'walkin'])
          .order('time_start');
      if (!mounted) return;
      setState(() {
        _tables = List<Map<String, dynamic>>.from(tablesRes);
        _bookings = List<Map<String, dynamic>>.from(bookingsRes);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _guestName(Map<String, dynamic> b) {
    final g = b['guests'];
    if (g == null) return 'OSPITE';
    final fn = (g['first_name'] ?? '').toString().trim();
    final sn = (g['surname'] ?? '').toString().trim();
    if (fn.isNotEmpty) return fn;
    if (sn.isNotEmpty) return sn.toUpperCase();
    return (g['name'] ?? 'OSPITE').toString();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return AppColors.textPrimary;
      case 'seated':   return AppColors.statoConfermato;
      case 'pending':  return AppColors.statoAttesa;
      case 'walkin':   return AppColors.statoAlTavolo;
      default:         return AppColors.textMuted;
    }
  }

  bool _isLight(String status) => status == 'pending';

  double _timeToX(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? _startHour;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return ((h - _startHour) * 60 + m) / _slotMinutes * _slotWidth;
  }

  double _durationToWidth(String s, String e) {
    final p0 = s.split(':');
    final p1 = e.split(':');
    final m0 = (int.tryParse(p0[0]) ?? 0) * 60 + (int.tryParse(p0[1]) ?? 0);
    final m1 = (int.tryParse(p1[0]) ?? 0) * 60 + (int.tryParse(p1[1]) ?? 0);
    return (m1 - m0).clamp(30, 240) / _slotMinutes * _slotWidth;
  }

  List<String> get _slots {
    final slots = <String>[];
    for (int h = _startHour; h < _endHour; h++) {
      for (int m = 0; m < 60; m += _slotMinutes) {
        slots.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      }
    }
    return slots;
  }

  // Returns how many bookings and guests are "active" at each slot
  Map<String, (int, int)> get _slotOccupancy {
    final c = <String, (int, int)>{};
    for (final slot in _slots) {
      final slotParts = slot.split(':');
      final slotMin = int.parse(slotParts[0]) * 60 + int.parse(slotParts[1]);
      int bookingsCount = 0, guestsCount = 0;
      for (final b in _bookings) {
        final ts = (b['time_start'] ?? '').toString().substring(0, 5);
        final te = (b['time_end'] ?? '').toString().substring(0, 5);
        if (ts.isEmpty) continue;
        final tsParts = ts.split(':');
        final tsMin = int.parse(tsParts[0]) * 60 + int.parse(tsParts[1]);
        int teMin = tsMin + 120;
        if (te.isNotEmpty && te.contains(':')) {
          final teParts = te.split(':');
          teMin = int.parse(teParts[0]) * 60 + int.parse(teParts[1]);
        }
        if (slotMin >= tsMin && slotMin < teMin) {
          bookingsCount++;
          guestsCount += (b['party_size'] as int? ?? 0);
        }
      }
      c[slot] = (bookingsCount, guestsCount);
    }
    return c;
  }

  Map<String, List<Map<String, dynamic>>> get _tablesByArea {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final t in _tables) {
      final area = t['areas']?['name']?.toString() ?? 'Altro';
      map.putIfAbsent(area, () => []).add(t);
    }
    for (final key in map.keys) {
      map[key]?.sort((a, b) {
        final an = int.tryParse(a['name']?.toString() ?? '') ?? 999;
        final bn = int.tryParse(b['name']?.toString() ?? '') ?? 999;
        return an.compareTo(bn);
      });
    }
    const order = ['BANCONE', 'DEHORS', 'INTERNO'];
    final sorted = <String, List<Map<String, dynamic>>>{};
    for (final area in order) {
      if (map.containsKey(area)) sorted[area] = map[area]!;
    }
    for (final key in map.keys) {
      if (!sorted.containsKey(key)) sorted[key] = map[key]!;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);

    // Listen to date changes and reload
    ref.listen(selectedDateProvider, (_, __) => _load());

    final slots = _slots;
    final totalWidth = _labelWidth + slots.length * _slotWidth;
    final occupancy = _slotOccupancy;
    final tablesByArea = _tablesByArea;
    final totalBookings = _bookings.length;
    final totalGuests = _bookings.fold<int>(0, (s, b) => s + ((b['party_size'] as int?) ?? 0));
    final noTableBookings = _bookings.where((b) => b['table_id'] == null).toList();

    return Column(children: [
      // ── Date header ────────────────────────────────────────────────────────
      // Fondo pagina, non bianco: cosi' il riquadro della griglia qui sotto
      // stacca dallo sfondo come i box del pannello di controllo.
      Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(children: [
          Text(
            DateFormat('EEEE d MMM yyyy', 'it_IT').format(selectedDate),
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Aperto',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
        ]),
      ),
      Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        child: Row(children: [
          _statChip('Totale', totalBookings, totalGuests),
          const SizedBox(width: 8),
          _statChip('Altro', noTableBookings.length, noTableBookings.fold(0, (s, b) => s + ((b['party_size'] as int?) ?? 0))),
          const SizedBox(width: 8),
          _statChip('Residuo', totalBookings - noTableBookings.length,
              totalGuests - noTableBookings.fold(0, (s, b) => s + ((b['party_size'] as int?) ?? 0))),
        ]),
      ),

      // ── Timeline ───────────────────────────────────────────────────────────
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
      else
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Stack(children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTurniStrip(slots.length * _slotWidth),
                    // Time slot header
                    _buildSlotHeader(slots),
                    // Occupancy counter row
                    _buildOccupancyRow(slots, occupancy),
                    const Divider(height: 1, color: AppColors.divider),

                    // Pending / no-table bookings
                    if (noTableBookings.isNotEmpty) ...[
                      _buildAreaLabel('Nessun tavolo!', slots, isNoTable: true),
                      ...noTableBookings.map((b) => _buildBookingRow(context, b, slots, isNoTable: true)),
                    ],

                    // Area sections
                    ...tablesByArea.entries.map((entry) {
                      final occupati = entry.value
                          .where((t) => _bookings.any(
                              (b) => b['table_id']?.toString() == t['id']?.toString()))
                          .length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAreaLabel(entry.key, slots,
                              tavoli: entry.value.length, occupati: occupati),
                          ...entry.value.map((table) => _buildTableRow(context, table, slots)),
                        ],
                      );
                    }),
                  ],
                ),
                // A servizio in corso è l'informazione più utile della
                // schermata, e prima non c'era. Solo guardando oggi.
                if (_xAdesso(selectedDate) != null)
                  Positioned(
                    left: _labelWidth + _xAdesso(selectedDate)!,
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: Container(color: AppColors.accent),
                  ),
                ]),
              ),
            ),
          ),
          ),
        ),
    ]);
  }

  /// Dove cade l'ora corrente nella griglia, `null` se non serve mostrarla.
  double? _xAdesso(DateTime giornoMostrato) {
    final ora = DateTime.now();
    final stessoGiorno = giornoMostrato.year == ora.year &&
        giornoMostrato.month == ora.month &&
        giornoMostrato.day == ora.day;
    if (!stessoGiorno) return null;
    if (ora.hour < _startHour || ora.hour >= _endHour) return null;
    return _timeToX('${ora.hour}:${ora.minute}');
  }

  Widget _statChip(String label, int count, int guests) {
    return Text(
      '$label $count • $guests',
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    );
  }

  static const double _larghezzaOra = _slotWidth * 60 / _slotMinutes;

  /// Le ore in cui il fondo è appena più scuro, per dare ritmo alla griglia.
  static bool _bandaOra(int ora) => ora.isOdd;

  /// I turni del locale, come li sceglie il cliente nel modulo.
  static const _turni = <(String, String, String)>[
    ('Aperitivo', '18:30', '20:00'),
    ('1º turno', '20:00', '22:00'),
    ('2º turno', '22:00', '23:00'),
  ];

  /// Striscia dei turni sopra le ore.
  ///
  /// È il ritmo con cui si lavora davvero: guardando la griglia si devono
  /// vedere i turni, non solo i minuti. Nera e oro come la barra del marchio,
  /// così non ruba il significato ai colori delle sale.
  Widget _buildTurniStrip(double larghezzaGriglia) {
    return Container(
      color: AppColors.nero,
      height: 26,
      child: Row(children: [
        const SizedBox(width: _labelWidth),
        SizedBox(
          width: larghezzaGriglia,
          child: Stack(children: [
            for (final t in _turni)
              Positioned(
                left: _timeToX('${t.$2}:00'),
                width: _timeToX('${t.$3}:00') - _timeToX('${t.$2}:00'),
                top: 0,
                bottom: 0,
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                      border: Border(
                          left: BorderSide(color: AppColors.gold, width: 1))),
                  child: Text(t.$1,
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.clip),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  /// Le ore, in orizzontale e solo piene.
  ///
  /// Erano scritte in verticale una ogni quarto d'ora: ventiquattro etichette
  /// ruotate che nessuno legge. I quarti restano come tacche, servono a
  /// posizionare i blocchi, non a essere letti.
  Widget _buildSlotHeader(List<String> slots) {
    return Container(
      color: AppColors.surface,
      height: 30,
      child: Row(children: [
        const SizedBox(width: _labelWidth),
        for (int h = _startHour; h < _endHour; h++)
          Container(
            width: _larghezzaOra,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _bandaOra(h) ? AppColors.background : null,
              border: const Border(
                  left: BorderSide(color: AppColors.divider, width: 1)),
            ),
            child: Text('$h',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  /// Le celle vuote di una riga: banda alternata per ora, linea marcata
  /// sull'ora piena e capello sui quarti.
  List<Widget> _celleGriglia(List<String> slots) {
    return [
      for (final s in slots)
        Builder(builder: (_) {
          final oraPiena = s.endsWith(':00');
          final h = int.tryParse(s.split(':')[0]) ?? _startHour;
          return Container(
            width: _slotWidth,
            decoration: BoxDecoration(
              color: _bandaOra(h)
                  ? Colors.black.withValues(alpha: 0.022)
                  : null,
              border: Border(
                left: BorderSide(
                  color: oraPiena
                      ? AppColors.divider
                      : AppColors.divider.withValues(alpha: 0.45),
                  width: oraPiena ? 1 : 0.5,
                ),
              ),
            ),
          );
        }),
    ];
  }

  // ── Occupancy counter row ──────────────────────────────────────────────────
  Widget _buildOccupancyRow(List<String> slots, Map<String, (int, int)> occupancy) {
    return Container(
      color: AppColors.background,
      height: 22,
      child: Row(children: [
        SizedBox(width: _labelWidth),
        ...slots.map((slot) {
          final (b, g) = occupancy[slot] ?? (0, 0);
          final hasData = b > 0;
          return SizedBox(
            width: _slotWidth,
            child: Center(
              child: Text(
                hasData ? '$b•$g' : '·',
                style: TextStyle(
                  color: hasData ? AppColors.textSecondary : AppColors.divider,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }

  // ── Area / section label row ───────────────────────────────────────────────
  /// Barra piena di inizio sala.
  ///
  /// Era una striscia grigia con dentro una scritta piccola: scorrendo, dopo
  /// tre righe non si sapeva piu' in quale sala si stesse guardando. Ora la
  /// barra e' del colore della sala e porta a destra quanti tavoli sono
  /// occupati, che e' la cosa che si cerca davvero.
  Widget _buildAreaLabel(String name, List<String> slots,
      {bool isNoTable = false, int tavoli = 0, int occupati = 0}) {
    final c = isNoTable ? ColoriSala.senzaTavolo : ColoriSala.di(name);
    final riassunto = isNoTable
        ? ''
        : occupati == 0
            ? '$tavoli tavoli · tutti liberi'
            : '$tavoli tavoli · $occupati occupati';

    return Container(
      color: c.forte,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      // Il nome non e' piu' rinchiuso nella colonna dei numeri: li' dentro
      // "Bancone" diventava "Banc..." e "Dehors" spariva a meta'. La barra
      // e' larga quanto tutta la riga, tanto vale usarla.
      child: Row(children: [
        Icon(c.icona, size: 17, color: c.suForte),
        const SizedBox(width: 8),
        Text(_nomeSala(name),
            style: TextStyle(
                color: c.suForte, fontWeight: FontWeight.bold, fontSize: 15)),
        if (riassunto.isNotEmpty) ...[
          const SizedBox(width: 14),
          Text(riassunto,
              style: TextStyle(
                  color: c.suForte.withValues(alpha: 0.88), fontSize: 13)),
        ],
      ]),
    );
  }

  /// "BANCONE" gridato diventa "Bancone": le maiuscole piene si leggono peggio
  /// e qui il colore fa gia' tutto il lavoro di far notare la riga.
  String _nomeSala(String n) {
    final s = n.trim().toLowerCase();
    return s.isEmpty ? n : s[0].toUpperCase() + s.substring(1);
  }

  // ── Row for no-table booking ───────────────────────────────────────────────
  Widget _buildBookingRow(
    BuildContext context,
    Map<String, dynamic> b,
    List<String> slots, {
    bool isNoTable = false,
  }) {
    final timeStart = (b['time_start'] ?? '${_startHour}:00:00').toString();
    final timeEnd = (b['time_end'] ?? '').toString();
    final x = _labelWidth + _timeToX(timeStart);
    final w = timeEnd.isNotEmpty ? _durationToWidth(timeStart, timeEnd) : _slotWidth * 4.0;
    const color = AppColors.gold;

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
          color: ColoriSala.senzaTavolo.tintaGriglia,
          border: const Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5))),
      child: Stack(children: [
        Row(children: [
          Container(
            width: _labelWidth,
            // Stessa banda delle sale, in oro: queste righe non appartengono
            // a nessuna sala perche' il tavolo non e' ancora stato assegnato.
            decoration: BoxDecoration(
              color: ColoriSala.senzaTavolo.tinta,
              border: Border(
                  left: BorderSide(color: ColoriSala.senzaTavolo.forte, width: 4)),
            ),
          ),
          ..._celleGriglia(slots),
        ]),
        Positioned(
          left: x, top: 5, height: _rowHeight - 10, width: w.clamp(80.0, 500.0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showDetail(context, b),
            child: _BookingBar(
              booking: b,
              guestName: _guestName(b),
              color: color,
              lightContent: true,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Table row ─────────────────────────────────────────────────────────────
  Widget _buildTableRow(
      BuildContext context, Map<String, dynamic> table, List<String> slots) {
    final tableId = table['id']?.toString();
    final tableName = table['name']?.toString() ?? '';
    final capacity = (table['capacity'] as int?) ?? 0;
    final tableBookings =
        _bookings.where((b) => b['table_id']?.toString() == tableId).toList();
    final c = ColoriSala.di(table['areas']?['name']?.toString());

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
          // La tinta attraversa tutta la riga: prima il colore moriva alla
          // colonna del numero e a destra restava mezzo schermo di beige.
          color: c.tintaGriglia,
          border: const Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5))),
      child: Stack(children: [
        Row(children: [
          Container(
            width: _labelWidth,
            // Banda del colore della sala a sinistra e fondo piu' carico:
            // a meta' scorrimento si sa dove si e' senza risalire in cima.
            decoration: BoxDecoration(
              color: c.tinta,
              border: Border(left: BorderSide(color: c.forte, width: 4)),
            ),
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(children: [
              Text(tableName,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: c.forte.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$capacity',
                    style: TextStyle(
                        color: c.forte, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          ..._celleGriglia(slots),
        ]),
        ...tableBookings.map((b) {
          final timeStart = (b['time_start'] ?? '${_startHour}:00:00').toString();
          final timeEnd = (b['time_end'] ?? '').toString();
          final x = _labelWidth + _timeToX(timeStart);
          final w = timeEnd.isNotEmpty ? _durationToWidth(timeStart, timeEnd) : _slotWidth * 4.0;
          final status = b['status'] as String? ?? '';
          final color = _statusColor(status);
          return Positioned(
            left: x, top: 5, height: _rowHeight - 10, width: w - 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showDetail(context, b),
              child: _BookingBar(
                booking: b,
                guestName: _guestName(b),
                color: color,
                lightContent: _isLight(status),
              ),
            ),
          );
        }),
      ]),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BookingDetailSheet(
        booking: b,
        onSaved: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }
}

// ── Booking bar widget ─────────────────────────────────────────────────────

class _BookingBar extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String guestName;
  final Color color;
  final bool lightContent;

  const _BookingBar({
    required this.booking,
    required this.guestName,
    required this.color,
    required this.lightContent,
  });

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? '';
    final partySize = booking['party_size'] as int? ?? 0;
    final hasEmail = (booking['guests']?['email'] as String? ?? '').isNotEmpty;
    final contentColor = lightContent ? Colors.black87 : Colors.white;
    final circleColor = lightContent ? Colors.black26 : Colors.white24;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        Expanded(
          child: Text(guestName,
              style: TextStyle(
                  color: contentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 4),
        // Party size circle
        Container(
          width: 21, height: 21,
          decoration: BoxDecoration(shape: BoxShape.circle, color: circleColor),
          child: Center(
            child: Text('$partySize',
                style: TextStyle(color: contentColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        if (hasEmail && !lightContent) ...[
          const SizedBox(width: 3),
          Icon(Icons.mail_outline, size: 12, color: contentColor.withValues(alpha:0.8)),
        ],
        const SizedBox(width: 3),
        Icon(Icons.timer_outlined, size: 12, color: contentColor.withValues(alpha:0.8)),
        const SizedBox(width: 3),
        Icon(
          status == 'pending' ? Icons.info_outline : Icons.thumb_up_outlined,
          size: 12,
          color: contentColor.withValues(alpha:0.8),
        ),
      ]),
    );
  }
}

