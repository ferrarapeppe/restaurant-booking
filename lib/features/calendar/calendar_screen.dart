import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';

// Provider per il mese focalizzato
final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime(DateTime.now().year, DateTime.now().month));

// Provider per i conteggi del mese
final monthBookingCountsProvider = FutureProvider.autoDispose<Map<String, Map<String, int>>>((ref) async {
  final month = ref.watch(focusedMonthProvider);
  return ref.read(bookingRepositoryProvider).getBookingCountsByMonth(month.year, month.month);
});

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});
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
        title: const Text('Calendario', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: const _CalendarBody(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => context.push('/bookings/new'),
      ),
    );
  }
}

class _CalendarBody extends ConsumerStatefulWidget {
  const _CalendarBody();
  @override
  ConsumerState<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends ConsumerState<_CalendarBody> {
  final Set<int> _closedWeekdays = {};

  bool _isClosed(DateTime day) => _closedWeekdays.contains(day.weekday - 1);
  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

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
    final days = _getDaysInMonth(focusedMonth);
    final monthName = DateFormat('MMMM', 'it_IT').format(focusedMonth);
    final capitalMonth = monthName[0].toUpperCase() + monthName.substring(1);

    return Column(children: [
      // Header mese
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => ref.read(focusedMonthProvider.notifier).state = DateTime(focusedMonth.year, focusedMonth.month - 1),
          ),
          Expanded(child: Text('$capitalMonth ${focusedMonth.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold))),
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
      // Giorni settimana
      Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(children: ['Lun','Mar','Mer','Gio','Ven','Sab','Dom'].map((d) => Expanded(
          child: Center(child: Text(d, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
        )).toList()),
      ),
      const Divider(height: 1, color: AppColors.divider),
      // Griglia
      Expanded(
        child: countsAsync.when(
          loading: () => GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.52),
            itemCount: days.length,
            itemBuilder: (_, i) => _DayCell(day: days[i], focusedMonth: focusedMonth, isSelected: _isSameDay(days[i], selectedDay), counts: null, isClosed: false),
          ),
          error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppColors.textSecondary))),
          data: (counts) => GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.52),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final key = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
              final dayData = counts[key];
              return GestureDetector(
                onTap: () {
                  if (day.month == focusedMonth.month) {
                    ref.read(selectedDateProvider.notifier).state = day;
                    context.go('/bookings');
                  }
                },
                child: _DayCell(
                  day: day,
                  focusedMonth: focusedMonth,
                  isSelected: _isSameDay(day, selectedDay),
                  counts: dayData,
                  isClosed: _isClosed(day) && day.month == focusedMonth.month,
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day, focusedMonth;
  final bool isSelected, isClosed;
  final Map<String, int>? counts;
  const _DayCell({required this.day, required this.focusedMonth, required this.isSelected, required this.isClosed, required this.counts});

  bool get _isCurrentMonth => day.month == focusedMonth.month;
  bool get _isToday { final n = DateTime.now(); return day.year == n.year && day.month == n.month && day.day == n.day; }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accentLight : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isToday ? AppColors.accent : AppColors.divider, width: _isToday ? 2 : 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 5, 0, 2),
          child: Text('${day.day}', style: TextStyle(
            color: !_isCurrentMonth ? AppColors.textMuted : _isToday ? AppColors.accent : AppColors.textPrimary,
            fontSize: 14, fontWeight: _isToday ? FontWeight.bold : FontWeight.w500,
          )),
        ),
        if (isClosed)
          _Pill(label: 'Chiuso', bg: const Color(0xFF3A2A00), fg: const Color(0xFFFFC107))
        else if (counts != null && _isCurrentMonth) ...[
          _Pill(label: '${counts!['bookings']} pre', bg: const Color(0xFF1A2A1A), fg: const Color(0xFF4CAF50)),
          const SizedBox(height: 1),
          _Pill(label: '${counts!['guests']} pe', bg: const Color(0xFF1A1A2A), fg: const Color(0xFF90CAF9)),
        ],
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label; final Color bg, fg;
  const _Pill({required this.label, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    padding: const EdgeInsets.symmetric(vertical: 1),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: fg, fontSize: 9, fontWeight: FontWeight.w700)),
  );
}
