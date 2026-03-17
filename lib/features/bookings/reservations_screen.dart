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
