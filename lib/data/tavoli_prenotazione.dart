import 'package:supabase_flutter/supabase_flutter.dart';

/// I tavoli assegnati alle prenotazioni.
///
/// Una prenotazione può tenerne più d'uno: cinque persone nel dehors, dove i
/// tavoli sono tutti da due, occupano tre tavoli. La verità sta in
/// `booking_tables`; `bookings.table_id` resta allineato al primo tavolo
/// perché metà dell'app lo legge ancora, ma **non va usato per sapere se un
/// tavolo è libero**: vedrebbe un tavolo solo per prenotazione, e darebbe per
/// libero un tavolo occupato.
class TavoliPrenotazione {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Tavoli di ogni prenotazione di una giornata: `id prenotazione -> tavoli`.
  ///
  /// Una richiesta sola per l'intera giornata invece di una per prenotazione:
  /// la planimetria ne mostra decine insieme.
  static Future<Map<String, List<String>>> perGiornata(String dataIso) async {
    final res = await _db
        .from('booking_tables')
        .select('booking_id, table_id, bookings!inner(date)')
        .eq('bookings.date', dataIso);
    return _raggruppa(res);
  }

  /// Tavoli di prenotazioni specifiche.
  static Future<Map<String, List<String>>> perPrenotazioni(
      List<String> idPrenotazioni) async {
    if (idPrenotazioni.isEmpty) return {};
    final res = await _db
        .from('booking_tables')
        .select('booking_id, table_id')
        .inFilter('booking_id', idPrenotazioni);
    return _raggruppa(res);
  }

  static Map<String, List<String>> _raggruppa(dynamic righe) {
    final mappa = <String, List<String>>{};
    for (final r in righe as List) {
      final b = (r as Map)['booking_id'].toString();
      mappa.putIfAbsent(b, () => []).add(r['table_id'].toString());
    }
    return mappa;
  }

  /// Sostituisce l'assegnazione di una prenotazione.
  ///
  /// Si cancella e si riscrive invece di calcolare le differenze: sono due o
  /// tre righe, e così non restano avanzi di un'assegnazione precedente.
  static Future<void> salva(String idPrenotazione, List<String> tavoli) async {
    await _db.from('booking_tables').delete().eq('booking_id', idPrenotazione);
    if (tavoli.isEmpty) {
      await _db.from('bookings').update({'table_id': null}).eq('id', idPrenotazione);
      return;
    }
    await _db.from('booking_tables').insert([
      for (final t in tavoli) {'booking_id': idPrenotazione, 'table_id': t},
    ]);
    // Il primo tavolo resta anche nella vecchia colonna, per le schermate
    // che non sono ancora passate alla tabella nuova.
    await _db
        .from('bookings')
        .update({'table_id': tavoli.first}).eq('id', idPrenotazione);
  }

  /// La proposta del motore sul server, la stessa che usa il modulo pubblico.
  ///
  /// `applica` a `false` propone e basta: la scelta resta al proprietario.
  static Future<Map<String, dynamic>?> proponi(
    String idPrenotazione, {
    bool applica = false,
  }) async {
    final res = await _db.functions.invoke('assegna-tavoli', body: {
      'prenotazione_id': idPrenotazione,
      'applica': applica,
    });
    final dati = res.data;
    return dati is Map ? Map<String, dynamic>.from(dati) : null;
  }
}
