import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gli avvisi Telegram che partono dall'app.
///
/// Nuova prenotazione e messaggio del cliente li manda il server, perche'
/// passano da `public-booking`. Il cambio di stato invece lo fa l'app
/// scrivendo dritto nel database, quindi l'avviso va chiesto da qui.
///
/// Il testo lo costruisce la funzione leggendo la prenotazione: se lo
/// mandasse l'app, un avviso potrebbe raccontare una cosa diversa da quella
/// che e' finita in archivio.
class AvvisiTelegram {
  /// Avvisa che una prenotazione e' stata annullata o segnata non presentata.
  ///
  /// Non aspetta l'esito e non solleva niente: un avviso non partito non deve
  /// far fallire il cambio di stato, che nel database e' gia' avvenuto.
  static void cambioStato(String idPrenotazione) {
    Supabase.instance.client.functions
        .invoke('telegram', body: {
          'azione': 'stato',
          'prenotazione_id': idPrenotazione,
        })
        .catchError((e) {
          debugPrint('avviso telegram non partito: $e');
          // `invoke` vuole comunque una risposta.
          return FunctionResponse(status: 0, data: null);
        });
  }
}
