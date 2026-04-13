import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';
import 'package:restaurant_booking/features/calendar/calendar_screen.dart';
import 'package:restaurant_booking/features/bookings/bookings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;


class ReservationsScreen extends ConsumerWidget {
  const ReservationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: Builder(builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () => Scaffold.of(context).openDrawer(),
        )),
        title: const Text('Programma', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.accent), onPressed: () => context.push('/bookings/new')),
        ],
      ),
      body: const _ScheduleTab(),
    );
  }
}

// ── CALENDARIO ──────────────────────────────────────────────
class _CalendarTab extends ConsumerWidget {
  const _CalendarTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CalendarBody();
  }
}


// ── LISTA ────────────────────────────────────────────────────
class _ListTab extends ConsumerWidget {
  const _ListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final filteredBookings = ref.watch(filteredBookingsProvider);
    final filterStatus = ref.watch(statusFilterProvider);
    final bookingsAsync = ref.watch(bookingsByDateProvider);
    final totalGuests = bookingsAsync.whenOrNull(data: (list) => list.fold(0, (s, b) => s + b.partySize)) ?? 0;
    final totalBookings = bookingsAsync.whenOrNull(data: (list) => list.length) ?? 0;

    return Column(children: [
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2024), lastDate: DateTime(2027), locale: const Locale('it', 'IT'));
              if (picked != null) ref.read(selectedDateProvider.notifier).state = picked;
            },
            child: Row(children: [
              Text(DateFormat('d MMM yyyy', 'it_IT').format(selectedDate), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
            ]),
          ),
          const Spacer(),
          _Chip(label: '$totalBookings pre', color: AppColors.accent),
          const SizedBox(width: 6),
          _Chip(label: '$totalGuests ospiti', color: AppColors.badgeGrey),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = selectedDate.subtract(const Duration(days: 1)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary), onPressed: () => ref.read(selectedDateProvider.notifier).state = selectedDate.add(const Duration(days: 1)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
      ),
      Container(
        color: AppColors.surface, height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          children: [
            for (final f in [('Tutti','tutti'),('Confermati','confirmed'),('In attesa','pending'),('Seduti','seated'),('Partiti','left'),('No-show','noshow'),('Walk-in','walkin')])
              GestureDetector(
                onTap: () => ref.read(statusFilterProvider.notifier).state = f.$2,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: filterStatus == f.$2 ? AppColors.accent : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: filterStatus == f.$2 ? AppColors.accent : AppColors.divider),
                  ),
                  child: Text(f.$1, style: TextStyle(color: filterStatus == f.$2 ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: filterStatus == f.$2 ? FontWeight.w600 : FontWeight.normal)),
                ),
              ),
          ],
        ),
      ),
      const Divider(height: 1, color: AppColors.divider),
      Expanded(
        child: filteredBookings.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
          error: (e, _) => Center(child: Text('Errore: $e')),
          data: (bookings) => bookings.isEmpty
              ? const Center(child: Text('Nessuna prenotazione', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return GestureDetector(
                      onTap: () => context.push('/bookings/detail', extra: booking),
                      child: BookingCard(booking: booking, onStatusChange: (s) async {
                        await ref.read(bookingRepositoryProvider).updateStatus(booking.id, s);
                        ref.invalidate(bookingsByDateProvider);
                      }),
                    );
                  },
                ),
        ),
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label; final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
  );
}

// ── SCHEDULE ─────────────────────────────────────────────────
class _ScheduleTab extends ConsumerStatefulWidget {
  const _ScheduleTab();
  @override
  ConsumerState<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends ConsumerState<_ScheduleTab> {
  static const _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _tables = [];
  bool _loading = false;

  static const _startHour = 17;
  static const _endHour = 23;
  static const _slotMinutes = 15;
  static const _slotWidth = 56.0;
  static const _rowHeight = 48.0;
  static const _labelWidth = 72.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final date = ref.read(selectedDateProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final supabase = supabase_flutter.Supabase.instance.client;
      final tablesRes = await supabase.from('tables').select('*, areas(name)').eq('restaurant_id', _restaurantId).order('name');
      final bookingsRes = await supabase.from('bookings').select('*, guests(first_name, surname, name), tables(name, areas(name))').eq('restaurant_id', _restaurantId).eq('date', dateStr).inFilter('status', ['confirmed', 'pending', 'seated', 'walkin']).order('time_start');
      setState(() {
        _tables = List<Map<String, dynamic>>.from(tablesRes);
        _bookings = List<Map<String, dynamic>>.from(bookingsRes);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _guestName(Map<String, dynamic> b) {
    final g = b['guests'];
    if (g == null) return 'OSPITE';
    final sn = (g['surname'] ?? '').toString().trim();
    if (sn.isNotEmpty) return sn.toUpperCase();
    final fn = (g['first_name'] ?? '').toString().trim();
    if (fn.isNotEmpty) return fn.toUpperCase();
    return (g['name'] ?? 'OSPITE').toString().toUpperCase();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return AppColors.accent;
      case 'seated':    return const Color(0xFF2E7D52);
      case 'pending':   return const Color(0xFFE65100);
      case 'walkin':    return const Color(0xFF007BFF);
      default:          return AppColors.textMuted;
    }
  }

  double _timeToX(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? _startHour;
    final m = int.tryParse(parts[1]) ?? 0;
    final totalMin = (h - _startHour) * 60 + m;
    return (totalMin / _slotMinutes) * _slotWidth;
  }

  double _durationToWidth(String timeStart, String timeEnd) {
    final p0 = timeStart.split(':');
    final p1 = timeEnd.split(':');
    final m0 = (int.tryParse(p0[0]) ?? 0) * 60 + (int.tryParse(p0[1]) ?? 0);
    final m1 = (int.tryParse(p1[0]) ?? 0) * 60 + (int.tryParse(p1[1]) ?? 0);
    final diff = (m1 - m0).clamp(30, 240);
    return (diff / _slotMinutes) * _slotWidth;
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

  Map<String, int> get _slotCounts {
    final counts = <String, int>{};
    for (final b in _bookings) {
      final t = (b['time_start'] ?? '00:00').toString().substring(0, 5);
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, List<Map<String, dynamic>>> get _tablesByArea {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final t in _tables) {
      final area = t['areas']?['name']?.toString() ?? 'Altro';
      map.putIfAbsent(area, () => []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime>(selectedDateProvider, (_, __) => _load());
    final slots = _slots;
    final totalWidth = _labelWidth + slots.length * _slotWidth;
    final slotCounts = _slotCounts;
    final tablesByArea = _tablesByArea;

    return Column(children: [
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary), onPressed: () { ref.read(selectedDateProvider.notifier).state = ref.read(selectedDateProvider).subtract(const Duration(days: 1)); _load(); }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: ref.read(selectedDateProvider), firstDate: DateTime(2024), lastDate: DateTime(2027), locale: const Locale('it', 'IT'));
              if (picked != null) { ref.read(selectedDateProvider.notifier).state = picked; _load(); }
            },
            child: Text(DateFormat('EEEE d MMM yyyy', 'it_IT').format(ref.watch(selectedDateProvider)), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
          const Spacer(),
          IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary), onPressed: () { ref.read(selectedDateProvider.notifier).state = ref.read(selectedDateProvider).add(const Duration(days: 1)); _load(); }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
      ),
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          Text('Totale ${_bookings.length}  •  ${_bookings.fold(0, (s, b) => s + ((b['party_size'] as int?) ?? 0))} ospiti', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
      ),
      const Divider(height: 1, color: AppColors.divider),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Riga orari
                  Container(
                    color: AppColors.surface,
                    height: 36,
                    child: Row(children: [
                      SizedBox(width: _labelWidth),
                      ...slots.map((slot) => SizedBox(
                        width: _slotWidth,
                        child: Center(child: slot.endsWith(':00')
                            ? Transform.rotate(angle: -3.14159 / 2, child: Text(slot, style: TextStyle(color: slot == '18:00' || slot == '20:00' ? AppColors.gold : AppColors.textSecondary, fontSize: 11, fontWeight: slot == '18:00' || slot == '20:00' ? FontWeight.bold : FontWeight.normal)))
                            : const SizedBox.shrink()),
                      )),
                    ]),
                  ),
                  // Riga contatori
                  Container(
                    color: AppColors.background,
                    height: 24,
                    child: Row(children: [
                      SizedBox(width: _labelWidth),
                      ...slots.map((slot) {
                        final count = slotCounts[slot] ?? 0;
                        return SizedBox(width: _slotWidth, child: Center(child: count > 0
                            ? Text('$count', style: TextStyle(color: count > 2 ? AppColors.accent : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold))
                            : Text('·', style: const TextStyle(color: AppColors.divider, fontSize: 10))));
                      }),
                    ]),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  // Aree e tavoli
                  ...tablesByArea.entries.map((entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        color: AppColors.cardLight, height: 32,
                        child: Row(children: [
                          SizedBox(width: _labelWidth, child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(entry.key.toUpperCase(), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)))),
                          ...slots.map((_) => Container(width: _slotWidth, decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.divider, width: 0.5))))),
                        ]),
                      ),
                      ...entry.value.map((table) {
                        final tableId = table['id']?.toString();
                        final tableName = table['name']?.toString() ?? '';
                        final capacity = table['capacity']?.toString() ?? '?';
                        final tableBookings = _bookings.where((b) => b['table_id']?.toString() == tableId).toList();
                        return Container(
                          height: _rowHeight,
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5))),
                          child: Stack(children: [
                            Row(children: [
                              Container(
                                width: _labelWidth, color: AppColors.surface,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(children: [
                                  Text(tableName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(10)),
                                    child: Text('$capacity-$capacity', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                                  ),
                                ]),
                              ),
                              ...slots.map((_) => Container(width: _slotWidth, decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.divider, width: 0.5))))),
                            ]),
                            ...tableBookings.map((b) {
                              final timeStart = (b['time_start'] ?? '${_startHour}:00:00').toString();
                              final timeEnd = (b['time_end'] ?? '').toString();
                              final x = _labelWidth + _timeToX(timeStart);
                              final w = timeEnd.isNotEmpty ? _durationToWidth(timeStart, timeEnd) : _slotWidth * 4;
                              final color = _statusColor(b['status'] ?? '');
                              return Positioned(
                                left: x, top: 4, height: _rowHeight - 8, width: w - 2,
                                child: GestureDetector(
                                  onTap: () => _showDetail(context, b),
                                  child: Container(
                                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Center(child: Text(_guestName(b), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                  ),
                                ),
                              );
                            }),
                          ]),
                        );
                      }),
                    ],
                  )),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }

  void _showDetail(BuildContext context, Map<String, dynamic> b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_guestName(b), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text((b['time_start'] ?? '').toString().substring(0, 5), style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(width: 16),
            const Icon(Icons.people_outline, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text('${b['party_size'] ?? 0}', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(width: 16),
            const Icon(Icons.table_restaurant_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(b['tables']?['name']?.toString() ?? 'Nessun tavolo', style: const TextStyle(color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Modifica'))),
          ]),
        ]),
      ),
    );
  }
}
