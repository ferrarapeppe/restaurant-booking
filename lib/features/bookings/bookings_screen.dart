import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final filteredBookings = ref.watch(filteredBookingsProvider);
    final filterStatus = ref.watch(statusFilterProvider);
    final bookingsAsync = ref.watch(bookingsByDateProvider);

    final totalGuests = bookingsAsync.whenOrNull(
          data: (list) => list.fold<int>(0, (sum, b) => sum + b.partySize),
        ) ??
        0;

    final totalBookings =
        bookingsAsync.whenOrNull(data: (list) => list.length) ?? 0;

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
        title: Text(
          DateFormat('d MMM yyyy', 'it_IT').format(selectedDate),
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _StatChip(
                    label: '$totalBookings prenotazioni',
                    color: AppColors.accent),
                const SizedBox(width: 8),
                _StatChip(
                    label: '$totalGuests ospiti',
                    color: AppColors.badgeGrey),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredBookings.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) =>
                  Center(child: Text('Errore: $e')),
              data: (bookings) => bookings.isEmpty
                  ? const Center(
                      child: Text('Nessuna prenotazione'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      itemBuilder: (context, index) {
                        final booking = bookings[index];
                        return Card(
                          child: ListTile(
                            title: Text(booking.guestName),
                            subtitle: Text(
                                '${booking.timeStart.substring(0, 5)} • ${booking.partySize} persone'),
                            trailing: Text(booking.status),
                            onTap: () => context.push(
                              '/bookings/detail',
                              extra: booking,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13)),
    );
  }
}
