import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';

class GuestRepository {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

  Future<List<GuestModel>> getGuests({String? search}) async {
    var query = _client
        .from('guests')
        .select()
        .eq('restaurant_id', _restaurantId);
    
    final response = await query.order('name', ascending: true);
    final guests = (response as List).map((e) => GuestModel.fromJson(e)).toList();
    
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      return guests.where((g) =>
        g.name.toLowerCase().contains(s) ||
        (g.phone?.contains(s) ?? false) ||
        (g.email?.toLowerCase().contains(s) ?? false)
      ).toList();
    }
    return guests;
  }

  Future<GuestModel> createGuest({
    required String name,
    String? email,
    String? phone,
    String? notes,
    List<String> tags = const [],
  }) async {
    final response = await _client
        .from('guests')
        .insert({
          'restaurant_id': _restaurantId,
          'name': name,
          'email': email,
          'phone': phone,
          'notes': notes,
          'tags': tags,
          'visits_count': 0,
        })
        .select()
        .single();
    return GuestModel.fromJson(response);
  }

  Future<void> updateGuest(String id, {
    String? name,
    String? email,
    String? phone,
    String? notes,
    List<String>? tags,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (phone != null) data['phone'] = phone;
    if (notes != null) data['notes'] = notes;
    if (tags != null) data['tags'] = tags;
    if (data.isNotEmpty) await _client.from('guests').update(data).eq('id', id);
  }

  Future<void> deleteGuest(String id) async {
    await _client.from('guests').delete().eq('id', id);
  }

  Future<List<BookingModel>> getGuestBookings(String guestId) async {
    final response = await _client
        .from('bookings')
        .select('*, guests(*)')
        .eq('guest_id', guestId)
        .order('date', ascending: false);
    return (response as List).map((e) => BookingModel.fromJson(e)).toList();
  }
}
