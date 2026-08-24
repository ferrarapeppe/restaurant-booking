import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stato delle prenotazioni online per una singola giornata.
enum StatoGiornata { inCaricamento, aperte, chiuse, chiusuraSettimanale, nonAncoraAperte, sconosciuto }

/// Le regole che decidono se il modulo pubblico accetta prenotazioni in una
/// data: la data di apertura scritta nel profilo e le righe di `opening_hours`.
///
/// Stanno qui perché le leggono sia l'elenco prenotazioni sia il calendario:
/// tenerne due copie le farebbe dire cose diverse sullo stesso giorno.
class RegoleGiornate {
  /// Data da cui il modulo comincia ad accettare prenotazioni (può mancare).
  final DateTime? apertura;
  final List<Map<String, dynamic>> _orari;

  RegoleGiornate({required this.apertura, required List<Map<String, dynamic>> orari}) : _orari = orari;

  static const idRistorante = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  static const titoloBlocco = 'Prenotazioni online sospese';

  static Future<RegoleGiornate> carica() async {
    final db = Supabase.instance.client;
    final profilo = await db.from('restaurants').select('settings').eq('id', idRistorante).single();
    final impostazioni = profilo['settings'];
    final iso = impostazioni is Map ? impostazioni['prenotazioni_dal']?.toString() : null;
    final righe = await db
        .from('opening_hours')
        .select('id, is_closed, special_date, day_of_week')
        .eq('restaurant_id', idRistorante);
    return RegoleGiornate(
      apertura: DateTime.tryParse(iso ?? ''),
      orari: [for (final r in righe) Map<String, dynamic>.from(r)],
    );
  }

  static DateTime _soloData(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Prima data prenotabile dal sito: mai nel passato, mai prima dell'apertura.
  DateTime get primaDataPrenotabile {
    final oggi = _soloData(DateTime.now());
    final a = apertura;
    return (a != null && _soloData(a).isAfter(oggi)) ? _soloData(a) : oggi;
  }

  Map<String, dynamic>? _speciale(DateTime giorno) {
    final iso = DateFormat('yyyy-MM-dd').format(giorno);
    for (final r in _orari) {
      final sd = r['special_date']?.toString();
      if (sd != null && sd.startsWith(iso)) return r;
    }
    return null;
  }

  Map<String, dynamic>? _settimanale(DateTime giorno) {
    final dow = (giorno.weekday - 1) % 7;
    for (final r in _orari) {
      if (r['special_date'] == null && r['day_of_week'] == dow) return r;
    }
    return null;
  }

  StatoGiornata stato(DateTime giorno) {
    if (_soloData(giorno).isBefore(primaDataPrenotabile)) return StatoGiornata.nonAncoraAperte;
    // Una data speciale vince sulla regola settimanale, come nel modulo.
    final speciale = _speciale(giorno);
    if (speciale != null) {
      return speciale['is_closed'] == true ? StatoGiornata.chiuse : StatoGiornata.aperte;
    }
    return _settimanale(giorno)?['is_closed'] == true
        ? StatoGiornata.chiusuraSettimanale
        : StatoGiornata.aperte;
  }

  /// Perché il modulo non accetta prenotazioni in quella data.
  String motivoNonAperta(DateTime giorno) {
    if (_soloData(giorno).isBefore(_soloData(DateTime.now()))) {
      return 'Data passata: il modulo non accetta prenotazioni.';
    }
    final a = apertura;
    return a == null
        ? 'Il modulo non accetta prenotazioni per questa data.'
        : 'Le prenotazioni online aprono il ${DateFormat('d MMMM yyyy', 'it_IT').format(a)}. '
            'Si cambia da Impostazioni → Profilo ristorante.';
  }

  /// Id della riga che blocca la giornata, da cancellare per riaprirla.
  String? idBlocco(DateTime giorno) {
    final speciale = _speciale(giorno);
    return speciale != null && speciale['is_closed'] == true ? speciale['id'] as String? : null;
  }

  /// Chiude le prenotazioni dal sito per quella data.
  /// Restituisce `null` se è andata a buon fine, altrimenti il motivo:
  /// PostgREST non solleva eccezioni quando una policy blocca la scrittura,
  /// torna zero righe, quindi le contiamo.
  static Future<String?> chiudi(DateTime giorno) async {
    final righe = await Supabase.instance.client.from('opening_hours').insert({
      'restaurant_id': idRistorante,
      'day_of_week': (giorno.weekday - 1) % 7,
      'special_date': DateFormat('yyyy-MM-dd').format(giorno),
      'is_closed': true,
      'open_time': '18:30:00',
      'close_time': '01:00:00',
      'title': titoloBlocco,
    }).select();
    return righe.isEmpty ? 'il database ha rifiutato la scrittura' : null;
  }

  static Future<String?> riapri(String idBlocco) async {
    final righe =
        await Supabase.instance.client.from('opening_hours').delete().eq('id', idBlocco).select();
    return righe.isEmpty ? 'il database ha rifiutato la cancellazione' : null;
  }
}

/// Aspetto del badge di stato, condiviso da elenco e calendario.
class AspettoStato {
  final String etichetta;
  final String breve;
  const AspettoStato(this.etichetta, this.breve);

  static AspettoStato di(StatoGiornata s) => switch (s) {
        StatoGiornata.aperte => const AspettoStato('Online aperte', 'Aperte'),
        StatoGiornata.chiuse => const AspettoStato('Online chiuse', 'Chiuse'),
        StatoGiornata.chiusuraSettimanale => const AspettoStato('Giorno di chiusura', 'Chiuso'),
        StatoGiornata.nonAncoraAperte => const AspettoStato('Non ancora aperte', 'Non aperte'),
        _ => const AspettoStato('Prenotazioni online', '…'),
      };
}
