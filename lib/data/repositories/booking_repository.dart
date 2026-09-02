import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';

class BookingRepository {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

  Future<List<BookingModel>> getBookingsByDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    print('DEBUG getBookingsByDate: $dateStr');
    final response = await _client
        .from('bookings')
        .select('*, guests(*)')
        .eq('restaurant_id', _restaurantId)
        .eq('date', dateStr)
        .order('time_start', ascending: true);
    return (response as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<Map<String, Map<String, int>>> getBookingCountsByMonth(int year, int month) async {
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
    final lastDay = DateTime(year, month + 1, 0).day;
    final endDate = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';
    final response = await _client
        .from('bookings')
        .select('date, party_size, status')
        .eq('restaurant_id', _restaurantId)
        .gte('date', startDate)
        .lte('date', endDate)
        // Cancellata dal locale vale come eliminata.
        .neq('status', 'canceled_by_venue');

    // Il calendario mostra solo le prenotazioni vive. Prima sommava tutto,
    // annullate comprese, mentre l'elenco di default mostra solo le attive:
    // la cella diceva "1 prenotaz." e aprendo il giorno non c'era niente.
    // I coperti seguono la stessa regola: una disdetta non occupa un tavolo.
    const spente = {'canceled', 'canceled_by_venue', 'rejected', 'no_show'};
    final Map<String, Map<String, int>> counts = {};
    for (final row in response as List) {
      if (spente.contains((row['status'] ?? '').toString())) continue;
      final d = row['date'] as String;
      counts[d] ??= {'prenotazioni': 0, 'ospiti': 0, 'pending': 0};
      counts[d]!['prenotazioni'] = (counts[d]?['prenotazioni'] ?? 0) + 1;
      counts[d]!['ospiti'] = (counts[d]?['ospiti'] ?? 0) + ((row['party_size'] as int?) ?? 0);
      if (row['status'] == 'pending') {
        counts[d]!['pending'] = (counts[d]?['pending'] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<BookingModel> createBooking(BookingModel booking) async {
    final response = await _client
        .from('bookings')
        .insert(booking.toJson())
        .select('*, guests(*)')
        .single();
    return BookingModel.fromJson(response);
  }

  Future<void> updateStatus(String id, String status) async {
    await _client.from('bookings').update({'status': status}).eq('id', id);
  }

  Future<void> deleteBooking(String id) async {
    await _client.from('bookings').delete().eq('id', id);
  }
}
