import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:restaurant_booking/data/repositories/booking_repository.dart';

// Repository provider
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository();
});

// Data selezionata
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Prenotazioni per data selezionata
final bookingsByDateProvider = FutureProvider.autoDispose<List<BookingModel>>((ref) async {
  final date = ref.watch(selectedDateProvider);
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getBookingsByDate(date);
});

// Conteggi per calendario
final bookingCountsProvider = FutureProvider.autoDispose.family<Map<String, Map<String, int>>, (int, int)>(
  (ref, params) async {
    final repo = ref.watch(bookingRepositoryProvider);
    return repo.getBookingCountsByMonth(params.$1, params.$2);
  },
);

// Filtro stato attivo
final statusFilterProvider = StateProvider<String>((ref) => 'tutti');

// Prenotazioni filtrate
final filteredBookingsProvider = Provider.autoDispose<AsyncValue<List<BookingModel>>>((ref) {
  final bookings = ref.watch(bookingsByDateProvider);
  final filter = ref.watch(statusFilterProvider);
  
  return bookings.whenData((list) {
    if (filter == 'tutti') return list;
    return list.where((b) => b.status == filter).toList();
  });
});
