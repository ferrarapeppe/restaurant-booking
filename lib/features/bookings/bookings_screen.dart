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



class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final Future<void> Function(String) onStatusChange;

  const BookingCard({super.key, required this.booking, required this.onStatusChange});

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return const Color(0xFF28A745);
      case 'seated': return const Color(0xFF007BFF);
      case 'left': return const Color(0xFF6C757D);
      case 'noshow': return const Color(0xFFDC3545);
      case 'walkin': return const Color(0xFF6F42C1);
      default: return const Color(0xFFFFC107);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'Confermato';
      case 'seated': return 'Seduto';
      case 'left': return 'Partito';
      case 'noshow': return 'No-show';
      case 'walkin': return 'Walk-in';
      default: return 'In attesa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(booking.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(
            booking.guestName.isNotEmpty ? booking.guestName[0].toUpperCase() : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20),
          )),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(booking.guestName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.access_time, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Text(booking.timeStart.substring(0, 5), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(width: 10),
            const Icon(Icons.people_outline, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 3),
            Text('${booking.partySize} persone', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (booking.guestPhone != null) ...[
              const SizedBox(width: 10),
              const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(booking.guestPhone!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ]),
          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(booking.notes!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
          ],
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showStatusMenu(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(_statusLabel(booking.status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  void _showStatusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        const Text('Cambia stato', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        for (final s in [('confirmed','Confermato'),('seated','Seduto'),('left','Partito'),('noshow','No-show')])
          ListTile(
            leading: CircleAvatar(radius: 8, backgroundColor: _statusColor(s.$1)),
            title: Text(s.$2),
            trailing: booking.status == s.$1 ? const Icon(Icons.check, color: AppColors.accent) : null,
            onTap: () { Navigator.pop(context); onStatusChange(s.$1); },
          ),
        const SizedBox(height: 16),
      ]),
    );
  }
}
