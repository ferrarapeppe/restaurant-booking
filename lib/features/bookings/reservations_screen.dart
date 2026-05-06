import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';
import 'package:restaurant_booking/features/bookings/bookings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;

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
        backgroundColor: AppColors.surface,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
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
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onPressed: () => ref.read(selectedDateProvider.notifier).state =
                  selectedDate.add(const Duration(days: 1)),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary),
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
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textSecondary),
            onPressed: () {},
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: AppColors.textSecondary),
                onPressed: () {},
              ),
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
  static const double _labelWidth = 76.0;

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
          .select('*, guests(first_name, surname, name, email), tables(name, areas(name))')
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
      case 'approved': return const Color(0xFF4A5568);
      case 'seated':   return const Color(0xFF2E7D52);
      case 'pending':  return const Color(0xFFFFC107);
      case 'walkin':   return const Color(0xFF007BFF);
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
      Container(
        color: AppColors.surface,
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
              color: const Color(0xFF2E7D52),
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
        color: AppColors.surface,
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
      const Divider(height: 1, color: AppColors.divider),

      // ── Timeline ───────────────────────────────────────────────────────────
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
      else
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    ...tablesByArea.entries.map((entry) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAreaLabel(entry.key, slots),
                        ...entry.value.map((table) => _buildTableRow(context, table, slots)),
                      ],
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _statChip(String label, int count, int guests) {
    return Text(
      '$label $count • $guests',
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
    );
  }

  // ── Slot header (rotated time labels) ──────────────────────────────────────
  Widget _buildSlotHeader(List<String> slots) {
    return Container(
      color: AppColors.surface,
      height: 44,
      child: Row(children: [
        SizedBox(width: _labelWidth),
        ...slots.map((slot) {
          final isHour = slot.endsWith(':00');
          final isHighlight = slot == '20:00' || slot == '21:00' || slot == '22:00';
          return SizedBox(
            width: _slotWidth,
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              RotatedBox(
                quarterTurns: 3,
                child: Text(slot,
                    style: TextStyle(
                      color: isHighlight
                          ? Colors.white
                          : (isHour ? AppColors.textSecondary : AppColors.textMuted),
                      fontSize: isHour ? 11 : 10,
                      fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
              const SizedBox(height: 3),
            ]),
          );
        }),
      ]),
    );
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
                  fontSize: 9,
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
  Widget _buildAreaLabel(String name, List<String> slots, {bool isNoTable = false}) {
    return Container(
      color: AppColors.cardLight,
      height: 30,
      child: Row(children: [
        SizedBox(
          width: _labelWidth,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: isNoTable
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(name,
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10),
                        overflow: TextOverflow.ellipsis),
                  )
                : Text(name.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
          ),
        ),
        ...slots.map((_) => Container(
            width: _slotWidth,
            decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.divider, width: 0.5))))),
      ]),
    );
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
    const color = Color(0xFFFFC107);

    return Container(
      height: _rowHeight,
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5))),
      child: Stack(children: [
        Row(children: [
          Container(
            width: _labelWidth,
            color: const Color(0xFFFFC107).withValues(alpha:0.08),
          ),
          ...slots.map((_) => Container(
              width: _slotWidth,
              decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.divider, width: 0.5))))),
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

    return Container(
      height: _rowHeight,
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5))),
      child: Stack(children: [
        Row(children: [
          Container(
            width: _labelWidth,
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              Text(tableName,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$capacity-$capacity',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
              ),
            ]),
          ),
          ...slots.map((_) => Container(
              width: _slotWidth,
              decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.divider, width: 0.5))))),
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 4),
        // Party size circle
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(shape: BoxShape.circle, color: circleColor),
          child: Center(
            child: Text('$partySize',
                style: TextStyle(color: contentColor, fontSize: 10, fontWeight: FontWeight.bold)),
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

