import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';
import 'package:restaurant_booking/features/bookings/bookings_screen.dart';


class ReservationsScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const ReservationsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Prenotazioni', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.accent), onPressed: () => context.push('/bookings/new')),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month_outlined, size: 20), text: 'Calendario'),
            Tab(icon: Icon(Icons.list_outlined, size: 20), text: 'Lista'),
            Tab(icon: Icon(Icons.view_timeline_outlined, size: 20), text: 'Schedule'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CalendarTab(),
          _ListTab(),
          _ScheduleTab(),
        ],
      ),
    );
  }
}

// ── CALENDARIO ──────────────────────────────────────────────
class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab();
  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  final Map<DateTime, Map<String, dynamic>> _events = {
    DateTime(2026, 2, 26): {'prenotazioni': 1, 'ospiti': 2},
    DateTime(2026, 3, 7): {'prenotazioni': 6, 'ospiti': 23},
    DateTime(2026, 3, 14): {'prenotazioni': 15, 'ospiti': 57},
  };
  final Set<int> _closedWeekdays = {0};

  bool _isClosed(DateTime day) => _closedWeekdays.contains(day.weekday - 1);
  Map<String, dynamic>? _getEvents(DateTime day) => _events[DateTime(day.year, day.month, day.day)];
  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday - 1;
    final days = <DateTime>[];
    for (int i = 0; i < startWeekday; i++) days.add(firstDay.subtract(Duration(days: startWeekday - i)));
    for (int i = 0; i < lastDay.day; i++) days.add(DateTime(_focusedMonth.year, _focusedMonth.month, i + 1));
    final remaining = 7 - (days.length % 7);
    if (remaining < 7) for (int i = 1; i <= remaining; i++) days.add(lastDay.add(Duration(days: i)));
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();
    final monthName = DateFormat('MMMM', 'it_IT').format(_focusedMonth);
    final capitalMonth = monthName[0].toUpperCase() + monthName.substring(1);

    return Column(children: [
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary), onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1))),
          Expanded(child: Text('$capitalMonth ${_focusedMonth.year}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary), onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1))),
          IconButton(icon: const Icon(Icons.today, color: AppColors.textSecondary, size: 20), onPressed: () => setState(() => _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month))),
        ]),
      ),
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(children: ['Lun','Mar','Mer','Gio','Ven','Sab','Dom'].map((d) => Expanded(
          child: Center(child: Text(d, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
        )).toList()),
      ),
      const Divider(height: 1, color: AppColors.divider),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.52),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final isCurrentMonth = day.month == _focusedMonth.month;
            final isToday = _isSameDay(day, DateTime.now());
            final isSelected = _selectedDay != null && _isSameDay(day, _selectedDay!);
            final events = _getEvents(day);
            final closed = _isClosed(day) && isCurrentMonth;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedDay = day);
                if (isCurrentMonth) {
                  ref.read(selectedDateProvider.notifier).state = day;
                }
              },
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentLight : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isToday ? AppColors.accent : AppColors.divider, width: isToday ? 2 : 0.5),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 5, 0, 2),
                    child: Text('${day.day}', style: TextStyle(
                      color: !isCurrentMonth ? AppColors.textMuted : isToday ? AppColors.accent : AppColors.textPrimary,
                      fontSize: 14, fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    )),
                  ),
                  if (closed)
                    _Pill(label: 'Chiuso', bg: const Color(0xFFFFF3CD), fg: const Color(0xFF856404))
                  else if (events != null && isCurrentMonth) ...[
                    _Pill(label: "${events['prenotazioni']} pre", bg: const Color(0xFFD4EDDA), fg: const Color(0xFF155724)),
                    const SizedBox(height: 1),
                    _Pill(label: "${events['ospiti']} pe", bg: const Color(0xFFE9ECEF), fg: const Color(0xFF495057)),
                  ],
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Pill({required this.label, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    padding: const EdgeInsets.symmetric(vertical: 1),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w700)),
  );
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
class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.view_timeline_outlined, size: 64, color: AppColors.textMuted),
      SizedBox(height: 16),
      Text('Schedule View', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('Timeline oraria — prossimamente', style: TextStyle(color: AppColors.textSecondary)),
    ]),
  );
}
