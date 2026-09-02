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

  /// Numero in formato internazionale, quando si capisce come.
  ///
  /// Senza questo, "3295631620" e "+393295631620" sono due clienti diversi per
  /// il database, e ogni prenotazione presa dall'app creava un doppione.
  static String? normalizzaTelefono(String? grezzo) {
    final testo = (grezzo ?? '').trim();
    if (testo.isEmpty) return null;
    final cifre = testo.replaceAll(RegExp(r'\D'), '');
    if (cifre.isEmpty) return null;
    if (testo.startsWith('+')) return '+' + cifre;
    if (cifre.startsWith('00')) return '+' + cifre.substring(2);
    if (cifre.length == 10 && cifre.startsWith('3')) return '+39' + cifre;  // cellulare
    if (cifre.startsWith('0') && cifre.length >= 9 && cifre.length <= 11) {
      return '+39' + cifre;                                                 // fisso
    }
    return '+' + cifre;
  }

  /// Cerca il cliente prima di crearne uno nuovo.
  ///
  /// Confronta l'email e le ultime nove cifre del telefono: bastano a
  /// riconoscere la stessa persona anche se il prefisso e' scritto in un altro
  /// modo, e non sono cosi' poche da confondere due numeri diversi.
  Future<(GuestModel, bool)> trovaOCrea({
    required String name,
    String? firstName,
    String? surname,
    String? email,
    String? phone,
  }) async {
    final mail = email?.trim().toLowerCase();
    final tel = normalizzaTelefono(phone);

    if (mail != null && mail.isNotEmpty) {
      final r = await _client
          .from('guests')
          .select()
          .eq('restaurant_id', _restaurantId)
          .eq('email', mail)
          .limit(1);
      if (r.isNotEmpty) return (GuestModel.fromJson(r.first), true);
    }

    if (tel != null) {
      final cifre = tel.replaceAll(RegExp(r'\D'), '');
      final ultime = cifre.length >= 9 ? cifre.substring(cifre.length - 9) : cifre;
      final r = await _client
          .from('guests')
          .select()
          .eq('restaurant_id', _restaurantId)
          .ilike('phone', '%' + ultime)
          .limit(1);
      if (r.isNotEmpty) return (GuestModel.fromJson(r.first), true);
    }

    final creato = await createGuest(
      name: name,
      firstName: firstName,
      surname: surname,
      email: mail,
      phone: tel,
    );
    return (creato, false);
  }

  Future<GuestModel> createGuest({
    required String name,
    String? firstName,
    String? surname,
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
          'first_name': firstName ?? name.split(' ').first,
          'surname': surname ?? (name.contains(' ') ? name.split(' ').sublist(1).join(' ') : ''),
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
    String? firstName,
    String? surname,
    String? email,
    String? phone,
    String? notes,
    List<String>? tags,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (firstName != null) data['first_name'] = firstName;
    if (surname != null) data['surname'] = surname;
    if (email != null) data['email'] = email;
    if (phone != null) data['phone'] = phone;
    if (notes != null) data['notes'] = notes;
    if (tags != null) data['tags'] = tags;
    if (data.isNotEmpty) await _client.from('guests').update(data).eq('id', id);
  }

  Future<void> deleteGuest(String id) async {
    // Prima scollega le prenotazioni (evita foreign key constraint)
    await _client.from('bookings').update({'guest_id': null}).eq('guest_id', id);
    // Poi elimina il cliente
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

  /// Le stesse prenotazioni, ma come righe grezze.
  ///
  /// `BookingDetailSheet` vuole la mappa e non il modello: le servono il
  /// tavolo e i recapiti del cliente, che `BookingModel` non porta con sé.
  /// Una query sola, poi la schermata ne ricava anche i modelli.
  Future<List<Map<String, dynamic>>> getGuestBookingsMappe(String guestId) async {
    final response = await _client
        .from('bookings')
        .select('*, guests(*), tables!bookings_table_id_fkey(id, name, capacity, area_id, areas(name))')
        .eq('guest_id', guestId)
        .order('date', ascending: false);
    return [for (final r in response as List) Map<String, dynamic>.from(r as Map)];
  }
}
