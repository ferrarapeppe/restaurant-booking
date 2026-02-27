import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';

/// Tavoli "prenotati" per la data selezionata.
/// Consideriamo attivi: confirmed, pending, seated, walkin.
/// (left / noshow NON evidenziano)
final bookedTableIdsProvider = Provider<Set<String>>((ref) {
  final bookingsAsync = ref.watch(bookingsByDateProvider);

  return bookingsAsync.maybeWhen(
    data: (list) {
      final booked = <String>{};

      for (final b in list) {
        final s = b.status.toLowerCase();
        final isActive = s == 'confirmed' || s == 'pending' || s == 'seated' || s == 'walkin';

        final tid = b.tableId;
        if (isActive && tid != null && tid.trim().isNotEmpty) {
          booked.add(tid.trim());
        }
      }
      return booked;
    },
    orElse: () => <String>{},
  );
});
