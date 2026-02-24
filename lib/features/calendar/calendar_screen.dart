import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  final Map<DateTime, Map<String, dynamic>> _events = {
    DateTime(2026, 2, 5): {'prenotazioni': 4, 'ospiti': 15},
    DateTime(2026, 2, 6): {'prenotazioni': 11, 'ospiti': 40},
    DateTime(2026, 2, 7): {'prenotazioni': 4, 'ospiti': 21},
    DateTime(2026, 2, 8): {'prenotazioni': 4, 'ospiti': 16},
    DateTime(2026, 2, 11): {'prenotazioni': 6, 'ospiti': 23},
    DateTime(2026, 2, 12): {'prenotazioni': 5, 'ospiti': 12},
    DateTime(2026, 2, 13): {'prenotazioni': 8, 'ospiti': 26},
    DateTime(2026, 2, 14): {'prenotazioni': 30, 'ospiti': 78},
    DateTime(2026, 2, 15): {'prenotazioni': 15, 'ospiti': 57},
    DateTime(2026, 2, 17): {'prenotazioni': 3, 'ospiti': 8},
    DateTime(2026, 2, 18): {'prenotazioni': 8, 'ospiti': 31},
    DateTime(2026, 2, 19): {'prenotazioni': 6, 'ospiti': 33},
    DateTime(2026, 2, 20): {'prenotazioni': 16, 'ospiti': 57},
    DateTime(2026, 2, 21): {'prenotazioni': 23, 'ospiti': 91},
    DateTime(2026, 2, 22): {'prenotazioni': 21, 'ospiti': 81},
    DateTime(2026, 2, 24): {'prenotazioni': 3, 'ospiti': 8},
    DateTime(2026, 2, 25): {'prenotazioni': 5, 'ospiti': 18},
    DateTime(2026, 2, 26): {'prenotazioni': 11, 'ospiti': 40},
    DateTime(2026, 2, 27): {'prenotazioni': 4, 'ospiti': 21},
    DateTime(2026, 2, 28): {'prenotazioni': 4, 'ospiti': 16},
  };

  final Set<int> _closedWeekdays = {0}; // Lunedì chiuso

  bool _isClosed(DateTime day) => _closedWeekdays.contains(day.weekday - 1);

  Map<String, dynamic>? _getEvents(DateTime day) =>
      _events[DateTime(day.year, day.month, day.day)];

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday - 1;
    final days = <DateTime>[];
    for (int i = 0; i < startWeekday; i++) {
      days.add(firstDay.subtract(Duration(days: startWeekday - i)));
    }
    for (int i = 0; i < lastDay.day; i++) {
      days.add(DateTime(_focusedMonth.year, _focusedMonth.month, i + 1));
    }
    final remaining = 7 - (days.length % 7);
    if (remaining < 7) {
      for (int i = 1; i <= remaining; i++) {
        days.add(lastDay.add(Duration(days: i)));
      }
    }
    return days;
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth();
    final monthName = DateFormat('MMMM', 'it_IT').format(_focusedMonth);
    final capitalMonth = monthName[0].toUpperCase() + monthName.substring(1);

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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
              onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
            ),
            Text('$capitalMonth ${_focusedMonth.year}',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
              onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today, color: AppColors.textSecondary),
              onPressed: () => setState(() => _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month))),
          IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Header mese
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text('$capitalMonth ', style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                Text('${_focusedMonth.year}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 22, fontWeight: FontWeight.w300)),
                const Spacer(),
                const Icon(Icons.more_vert, color: AppColors.textSecondary),
              ],
            ),
          ),
          // Header giorni settimana
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Griglia
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.52,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final isCurrentMonth = day.month == _focusedMonth.month;
                final isToday = isSameDay(day, DateTime.now());
                final isSelected = _selectedDay != null && isSameDay(day, _selectedDay!);
                final events = _getEvents(day);
                final closed = _isClosed(day) && isCurrentMonth;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = day);
                    if (isCurrentMonth) context.go('/bookings');
                  },
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accentLight : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday ? AppColors.accent : AppColors.divider,
                        width: isToday ? 2 : 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 5, 0, 2),
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: !isCurrentMonth
                                  ? AppColors.textMuted
                                  : isToday
                                      ? AppColors.accent
                                      : AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (closed && isCurrentMonth)
                          _PillBadge(
                            label: 'Chiuso',
                            bgColor: const Color(0xFFFFF3CD),
                            textColor: const Color(0xFF856404),
                          )
                        else if (events != null && isCurrentMonth) ...[
                          _PillBadge(
                            label: '${events['prenotazioni']} pre',
                            bgColor: const Color(0xFFD4EDDA),
                            textColor: const Color(0xFF155724),
                          ),
                          const SizedBox(height: 2),
                          _PillBadge(
                            label: '${events['ospiti']} pe',
                            bgColor: const Color(0xFFE9ECEF),
                            textColor: const Color(0xFF495057),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Info giorno selezionato
          if (_selectedDay != null)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    DateFormat('EEEE d MMMM', 'it_IT').format(_selectedDay!),
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_getEvents(_selectedDay!) != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFD4EDDA), borderRadius: BorderRadius.circular(8)),
                      child: Text('${_getEvents(_selectedDay!)!['prenotazioni']} prenotazioni',
                          style: const TextStyle(color: Color(0xFF155724), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE9ECEF), borderRadius: BorderRadius.circular(8)),
                      child: Text('${_getEvents(_selectedDay!)!['ospiti']} ospiti',
                          style: const TextStyle(color: Color(0xFF495057), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ] else
                    const Text('Nessuna prenotazione', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _PillBadge({required this.label, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}
