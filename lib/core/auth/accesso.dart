import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sezioni dell'app assegnabili a un membro dello staff.
///
/// Le chiavi devono restare allineate a quelle della funzione `manage-staff`,
/// che rifiuta i permessi che non riconosce.
class SezioneApp {
  final String chiave;
  final String etichetta;
  const SezioneApp(this.chiave, this.etichetta);
}

const sezioniApp = <SezioneApp>[
  SezioneApp('dashboard', 'Pannello di controllo'),
  SezioneApp('calendar', 'Calendario'),
  SezioneApp('reservations', 'Programma'),
  SezioneApp('bookings', 'Elenco prenotazioni'),
  SezioneApp('floor_plan', 'Planimetria'),
  SezioneApp('guests', 'Clienti'),
  SezioneApp('reports', 'Rapporti'),
  SezioneApp('assistente', 'Assistente'),
  SezioneApp('settings', 'Impostazioni'),
];

/// Percorso di partenza di ogni sezione.
String percorsoDiSezione(String chiave) => switch (chiave) {
      'dashboard' => '/',
      'calendar' => '/calendar',
      'reservations' => '/reservations',
      'bookings' => '/bookings',
      'floor_plan' => '/floor-plan/${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      'guests' => '/guests',
      'reports' => '/reports',
      'assistente' => '/assistente',
      _ => '/settings',
    };

/// Sezione a cui appartiene un percorso, `null` se e' sempre raggiungibile.
String? sezioneDelPercorso(String percorso) {
  if (percorso == '/') return 'dashboard';
  if (percorso.startsWith('/calendar')) return 'calendar';
  if (percorso.startsWith('/reservations')) return 'reservations';
  if (percorso.startsWith('/bookings')) return 'bookings';
  if (percorso.startsWith('/floor-plan')) return 'floor_plan';
  if (percorso.startsWith('/guests')) return 'guests';
  if (percorso.startsWith('/reports')) return 'reports';
  if (percorso.startsWith('/assistente')) return 'assistente';
  if (percorso.startsWith('/settings')) return 'settings';
  return null;
}

class ProfiloStaff {
  final String id, email, nome, ruolo;
  final List<String> sezioni;
  final bool attivo;

  const ProfiloStaff({
    required this.id,
    required this.email,
    required this.nome,
    required this.ruolo,
    required this.sezioni,
    required this.attivo,
  });

  bool get eAmministratore => ruolo == 'admin';

  /// L'amministratore vede tutto: le sezioni assegnate non lo riguardano.
  bool puoVedere(String chiave) => eAmministratore || sezioni.contains(chiave);

  factory ProfiloStaff.da(Map<String, dynamic> r) => ProfiloStaff(
        id: r['id'].toString(),
        email: (r['email'] ?? '').toString(),
        nome: (r['full_name'] ?? '').toString(),
        ruolo: (r['role'] ?? 'staff').toString(),
        sezioni: [for (final s in (r['sections'] as List? ?? const [])) s.toString()],
        attivo: r['active'] != false,
      );
}

/// Tiene traccia di chi e' entrato e di cosa gli e' permesso vedere.
///
/// E' un oggetto globale perche' lo consulta il router, che a sua volta e'
/// globale; `notifyListeners` lo fa ricalcolare a ogni cambio di sessione.
class StatoAccesso extends ChangeNotifier {
  StatoAccesso() {
    _caricaProfilo();
    _db.auth.onAuthStateChange.listen((_) => _caricaProfilo());
  }

  final _db = Supabase.instance.client;

  ProfiloStaff? profilo;
  bool inCaricamento = true;

  bool get autenticato =>
      _db.auth.currentSession != null && profilo != null && profilo!.attivo;

  /// Entrato ma senza riga nello staff, o disattivato: non e' del ristorante.
  bool get entratoSenzaProfilo =>
      _db.auth.currentSession != null && (profilo == null || !profilo!.attivo);

  Future<void> _caricaProfilo() async {
    final utente = _db.auth.currentUser;
    if (utente == null) {
      profilo = null;
      inCaricamento = false;
      notifyListeners();
      return;
    }
    try {
      final r = await _db
          .from('staff_members')
          .select('id, email, full_name, role, sections, active')
          .eq('id', utente.id)
          .maybeSingle();
      profilo = r == null ? null : ProfiloStaff.da(Map<String, dynamic>.from(r));
    } catch (e) {
      debugPrint('profilo staff non caricato: $e');
      profilo = null;
    }
    inCaricamento = false;
    notifyListeners();
  }

  /// Dove mandare chi entra: la prima sezione che gli e' concessa.
  String get percorsoIniziale {
    final p = profilo;
    if (p == null) return '/login';
    for (final s in sezioniApp) {
      if (p.puoVedere(s.chiave)) return percorsoDiSezione(s.chiave);
    }
    return '/senza-permessi';
  }

  Future<void> ricarica() => _caricaProfilo();

  Future<void> esci() async => await _db.auth.signOut();
}

final statoAccesso = StatoAccesso();
