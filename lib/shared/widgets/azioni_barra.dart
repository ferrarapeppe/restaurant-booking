import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

/// I pulsanti in alto a destra, condivisi da tutte le schermate.
///
/// Erano nove icone vive ma inerti: ci cliccavi e non succedeva niente, il che
/// e' peggio che vederle spente. Qui fanno tutte la stessa cosa ovunque.
///
/// [percorsoData] dice dove portare la scelta della data: `/bookings` oppure
/// `/floor-plan`. Se e' `null` l'icona del calendario non compare.
List<Widget> azioniBarra(BuildContext context, {String? percorsoData}) => [
      if (percorsoData != null)
        IconButton(
          tooltip: 'Vai a una data',
          icon: const Icon(Icons.calendar_today_outlined, color: Colors.white70),
          onPressed: () => scegliData(context, percorsoData),
        ),
      IconButton(
        tooltip: 'Cerca',
        icon: const Icon(Icons.search, color: Colors.white70),
        onPressed: () => apriRicerca(context),
      ),
      const _CampanellaConNumero(),
      const SizedBox(width: 4),
    ];

const _idRistorante = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

// ── Contatore delle cose in sospeso ─────────────────────────────────────────

/// Quante cose aspettano, contate una volta sola per tutta l'app.
///
/// Il numero serve in ogni schermata: se ognuna se lo calcolasse da se',
/// interrogherebbe il database a ogni ridisegno. Qui si conta all'avvio e poi
/// solo quando qualcosa cambia davvero, avvisati dal database stesso.
class ContatoreNotifiche extends ChangeNotifier {
  ContatoreNotifiche._();
  static final istanza = ContatoreNotifiche._();

  int daApprovare = 0;
  int senzaTavolo = 0;
  int get totale => daApprovare + senzaTavolo;

  bool _avviato = false;

  void avvia() {
    if (_avviato) return;
    _avviato = true;
    aggiorna();
    // Il canale non si tiene: questo contatore vive quanto l'app e non c'e'
    // un momento in cui vorremmo disiscriverci.
    Supabase.instance.client
        .channel('conteggio-notifiche')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          callback: (_) => aggiorna(),
        )
        .subscribe();
  }

  Future<void> aggiorna() async {
    try {
      final db = Supabase.instance.client;
      final oggi = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final attesa = await db
          .from('bookings')
          .select('id')
          .eq('restaurant_id', _idRistorante)
          .eq('source', 'web')
          .eq('status', 'pending');

      // Accettate ma ancora senza tavolo, da oggi in avanti: quelle passate
      // non si possono piu' sistemare.
      final senza = await db
          .from('bookings')
          .select('id')
          .eq('restaurant_id', _idRistorante)
          .isFilter('table_id', null)
          .gte('date', oggi)
          .inFilter('status', ['approved', 'pending']);

      daApprovare = attesa.length;
      senzaTavolo = senza.length;
      notifyListeners();
    } catch (e) {
      debugPrint('conteggio notifiche non riuscito: $e');
    }
  }
}

/// La campanella col numero delle cose in sospeso.
class _CampanellaConNumero extends StatefulWidget {
  const _CampanellaConNumero();

  @override
  State<_CampanellaConNumero> createState() => _CampanellaConNumeroState();
}

class _CampanellaConNumeroState extends State<_CampanellaConNumero> {
  @override
  void initState() {
    super.initState();
    ContatoreNotifiche.istanza.avvia();
    ContatoreNotifiche.istanza.addListener(_ridisegna);
  }

  @override
  void dispose() {
    ContatoreNotifiche.istanza.removeListener(_ridisegna);
    super.dispose();
  }

  void _ridisegna() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final n = ContatoreNotifiche.istanza.totale;
    return IconButton(
      tooltip: n == 0 ? 'Da sbrigare' : '$n da sbrigare',
      icon: Badge(
        isLabelVisible: n > 0,
        backgroundColor: AppColors.accent,
        textColor: Colors.white,
        label: Text(n > 99 ? '99+' : '$n'),
        child: const Icon(Icons.notifications_outlined, color: Colors.white70),
      ),
      onPressed: () => apriNotifiche(context),
    );
  }
}

// ── Scelta della data ────────────────────────────────────────────────────────

Future<void> scegliData(BuildContext context, String percorso) async {
  final oggi = DateTime.now();
  final scelta = await showDatePicker(
    context: context,
    initialDate: oggi,
    firstDate: DateTime(oggi.year - 2),
    lastDate: DateTime(oggi.year + 2),
    locale: const Locale('it', 'IT'),
  );
  if (scelta == null || !context.mounted) return;
  final iso = DateFormat('yyyy-MM-dd').format(scelta);
  context.go(percorso == '/floor-plan' ? '/floor-plan/$iso' : '/bookings?date=$iso');
}

// ── Ricerca ─────────────────────────────────────────────────────────────────

void apriRicerca(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SchedaRicerca(),
  );
}

class _SchedaRicerca extends StatefulWidget {
  const _SchedaRicerca();

  @override
  State<_SchedaRicerca> createState() => _SchedaRicercaState();
}

class _SchedaRicercaState extends State<_SchedaRicerca> {
  final _testo = TextEditingController();
  List<Map<String, dynamic>> _clienti = [];
  List<Map<String, dynamic>> _prenotazioni = [];
  bool _inCorso = false;
  String _ultimaChiave = '';

  @override
  void dispose() {
    _testo.dispose();
    super.dispose();
  }

  Future<void> _cerca(String q) async {
    final chiave = q.trim();
    if (chiave.length < 2) {
      setState(() {
        _clienti = [];
        _prenotazioni = [];
      });
      return;
    }
    _ultimaChiave = chiave;
    setState(() => _inCorso = true);
    try {
      final db = Supabase.instance.client;
      // Virgole e parentesi sono la punteggiatura del filtro `or`: lasciarle
      // passare romperebbe la ricerca appena qualcuno scrive "Rossi, Mario".
      // Restano fuori anche i caratteri jolly, che altrimenti farebbero
      // combaciare tutto.
      final pulita = chiave.replaceAll(RegExp(r'[,()%_*."\\]'), ' ').trim();
      if (pulita.isEmpty) {
        setState(() {
          _clienti = [];
          _prenotazioni = [];
          _inCorso = false;
        });
        return;
      }
      final like = '%$pulita%';
      final clienti = await db
          .from('guests')
          .select('id, name, first_name, surname, phone, email, visits_count')
          .eq('restaurant_id', _idRistorante)
          .or('name.ilike.$like,first_name.ilike.$like,surname.ilike.$like,'
              'phone.ilike.$like,email.ilike.$like')
          .limit(25);

      // Le prenotazioni si cercano tramite il cliente: nella tabella non c'e'
      // un nome da confrontare, solo il collegamento alla scheda.
      final idClienti = [for (final c in clienti) c['id'].toString()];
      List<dynamic> prenotazioni = const [];
      if (idClienti.isNotEmpty) {
        prenotazioni = await db
            .from('bookings')
            .select('id, date, time_start, party_size, status, guests(first_name, surname, name)')
            .eq('restaurant_id', _idRistorante)
            .inFilter('guest_id', idClienti)
            .order('date', ascending: false)
            .limit(30);
      }

      if (!mounted || _ultimaChiave != chiave) return;
      setState(() {
        _clienti = [for (final c in clienti) Map<String, dynamic>.from(c as Map)];
        _prenotazioni = [
          for (final p in prenotazioni) Map<String, dynamic>.from(p as Map)
        ];
        _inCorso = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _inCorso = false);
      debugPrint('ricerca non riuscita: $e');
    }
  }

  String _nome(Map<String, dynamic>? g) {
    if (g == null) return 'Ospite';
    final n = (g['first_name'] ?? '').toString().trim();
    final c = (g['surname'] ?? '').toString().trim();
    final unito = '$n $c'.trim();
    return unito.isNotEmpty ? unito : (g['name'] ?? 'Ospite').toString();
  }

  @override
  Widget build(BuildContext context) {
    final altezza = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: altezza * 0.85,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _testo,
              autofocus: true,
              onChanged: _cerca,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nome, cognome, telefono o email…',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _inCorso
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accent)),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(child: _risultati()),
        ]),
      ),
    );
  }

  Widget _risultati() {
    if (_testo.text.trim().length < 2) {
      return const _Vuoto(
        icona: Icons.search,
        testo: 'Scrivi almeno due lettere per cercare\nfra clienti e prenotazioni.',
      );
    }
    if (_clienti.isEmpty && _prenotazioni.isEmpty && !_inCorso) {
      return const _Vuoto(icona: Icons.person_off_outlined, testo: 'Nessun risultato.');
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      if (_clienti.isNotEmpty) ...[
        const _Titolo('Clienti'),
        for (final c in _clienti)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.goldLight,
              child: Icon(Icons.person_outline, color: AppColors.goldDark, size: 20),
            ),
            title: Text(_nome(c),
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(
              [c['phone'], c['email']]
                  .where((v) => (v ?? '').toString().trim().isNotEmpty)
                  .join('  ·  '),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: Text('${c['visits_count'] ?? 0} visite',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
        const SizedBox(height: 12),
      ],
      if (_prenotazioni.isNotEmpty) ...[
        const _Titolo('Prenotazioni'),
        for (final p in _prenotazioni)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppColors.accentLight,
              child: Icon(Icons.event_outlined, color: AppColors.accent, size: 20),
            ),
            title: Text(_nome(p['guests'] as Map<String, dynamic>?),
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${_dataLeggibile(p['date'])} · ${(p['time_start'] ?? '').toString().padRight(5).substring(0, 5)}'
              ' · ${p['party_size'] ?? 0} persone',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () {
              final iso = (p['date'] ?? '').toString().substring(0, 10);
              Navigator.pop(context);
              context.go('/bookings?date=$iso');
            },
          ),
      ],
    ]);
  }
}

/// L'area chiesta dal cliente nel modulo, per sapere dove cercargli posto.
String _areaRichiesta(Map<String, dynamic> b) {
  final grezzo = (b['internal_notes'] ?? '').toString().trim();
  if (!grezzo.startsWith('{')) return '';
  final m = RegExp(r'"area"\s*:\s*"([^"]*)"').firstMatch(grezzo);
  return (m?.group(1) ?? '').trim();
}

String _dataLeggibile(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '');
  return d == null ? '—' : DateFormat('EEE d MMM yyyy', 'it_IT').format(d);
}

// ── Notifiche ───────────────────────────────────────────────────────────────

void apriNotifiche(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SchedaNotifiche(),
  );
}

class _SchedaNotifiche extends StatefulWidget {
  const _SchedaNotifiche();

  @override
  State<_SchedaNotifiche> createState() => _SchedaNotificheState();
}

class _SchedaNotificheState extends State<_SchedaNotifiche> {
  List<Map<String, dynamic>> _daApprovare = [];
  List<Map<String, dynamic>> _senzaTavolo = [];
  List<Map<String, dynamic>> _messaggi = [];
  bool _inCorso = true;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final db = Supabase.instance.client;
      final attesa = await db
          .from('bookings')
          .select('id, date, time_start, party_size, guests(first_name, surname, name)')
          .eq('restaurant_id', _idRistorante)
          .eq('source', 'web')
          .eq('status', 'pending')
          .order('date')
          .limit(20);

      // Accettate ma ancora senza tavolo, da oggi in avanti: quelle passate
      // non si possono piu' sistemare.
      final senzaTavolo = await db
          .from('bookings')
          .select('id, date, time_start, party_size, status, internal_notes, guests(first_name, surname, name)')
          .eq('restaurant_id', _idRistorante)
          .isFilter('table_id', null)
          .gte('date', DateFormat('yyyy-MM-dd').format(DateTime.now()))
          .inFilter('status', ['approved', 'pending'])
          .order('date')
          .limit(30);

      // Ultimi messaggi scritti dai clienti dalla pagina di stato.
      final messaggi = await db
          .from('booking_messages')
          .select('id, message, created_at, booking_id, bookings(date, guests(first_name, surname, name))')
          .eq('sender', 'guest')
          .order('created_at', ascending: false)
          .limit(10);

      if (!mounted) return;
      setState(() {
        _daApprovare = [for (final a in attesa) Map<String, dynamic>.from(a as Map)];
        _senzaTavolo = [
          for (final s in senzaTavolo) Map<String, dynamic>.from(s as Map)
        ];
        _messaggi = [for (final m in messaggi) Map<String, dynamic>.from(m as Map)];
        _inCorso = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _inCorso = false);
      debugPrint('notifiche non caricate: $e');
    }
  }

  String _nome(Map<String, dynamic>? g) {
    if (g == null) return 'Ospite';
    final n = (g['first_name'] ?? '').toString().trim();
    final c = (g['surname'] ?? '').toString().trim();
    final unito = '$n $c'.trim();
    return unito.isNotEmpty ? unito : (g['name'] ?? 'Ospite').toString();
  }

  @override
  Widget build(BuildContext context) {
    final altezza = MediaQuery.of(context).size.height;
    return SizedBox(
      height: altezza * 0.7,
      child: Column(children: [
        const SizedBox(height: 10),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Da sbrigare',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: _inCorso
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : (_daApprovare.isEmpty && _senzaTavolo.isEmpty && _messaggi.isEmpty)
                  ? const _Vuoto(
                      icona: Icons.check_circle_outline,
                      testo: 'Non c\'è nulla in sospeso.')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (_daApprovare.isNotEmpty) ...[
                          _Titolo('${_daApprovare.length} da approvare'),
                          for (final b in _daApprovare)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.goldLight,
                                child: Icon(Icons.pending_actions,
                                    color: AppColors.goldDark, size: 20),
                              ),
                              title: Text(_nome(b['guests'] as Map<String, dynamic>?),
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${_dataLeggibile(b['date'])} · '
                                '${(b['time_start'] ?? '').toString().padRight(5).substring(0, 5)}'
                                ' · ${b['party_size'] ?? 0} persone',
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12),
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                              onTap: () {
                                final iso = (b['date'] ?? '').toString().substring(0, 10);
                                Navigator.pop(context);
                                context.go('/bookings?date=$iso');
                              },
                            ),
                          const SizedBox(height: 12),
                        ],
                        if (_senzaTavolo.isNotEmpty) ...[
                          _Titolo('${_senzaTavolo.length} senza tavolo'),
                          for (final b in _senzaTavolo)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.accentLight,
                                child: Icon(Icons.table_restaurant_outlined,
                                    color: AppColors.accent, size: 20),
                              ),
                              title: Text(_nome(b['guests'] as Map<String, dynamic>?),
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '${_dataLeggibile(b['date'])} · '
                                '${(b['time_start'] ?? '').toString().padRight(5).substring(0, 5)}'
                                ' · ${b['party_size'] ?? 0} persone'
                                '${_areaRichiesta(b) == '' ? '' : ' · ${_areaRichiesta(b)}'}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppColors.textMuted),
                              onTap: () {
                                final iso = (b['date'] ?? '').toString().substring(0, 10);
                                Navigator.pop(context);
                                context.go('/floor-plan/$iso');
                              },
                            ),
                          const SizedBox(height: 12),
                        ],
                        if (_messaggi.isNotEmpty) ...[
                          const _Titolo('Ultimi messaggi dai clienti'),
                          for (final m in _messaggi)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.accentLight,
                                child: Icon(Icons.chat_bubble_outline,
                                    color: AppColors.accent, size: 18),
                              ),
                              title: Text(
                                  _nome((m['bookings'] as Map<String, dynamic>?)?['guests']
                                      as Map<String, dynamic>?),
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                (m['message'] ?? '').toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12),
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                              onTap: () {
                                final data = (m['bookings'] as Map<String, dynamic>?)?['date'];
                                if (data == null) return;
                                Navigator.pop(context);
                                context.go(
                                    '/bookings?date=${data.toString().substring(0, 10)}');
                              },
                            ),
                        ],
                      ],
                    ),
        ),
      ]),
    );
  }
}

// ── Pezzi comuni ────────────────────────────────────────────────────────────

class _Titolo extends StatelessWidget {
  final String testo;
  const _Titolo(this.testo);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(testo.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6)),
      );
}

class _Vuoto extends StatelessWidget {
  final IconData icona;
  final String testo;
  const _Vuoto({required this.icona, required this.testo});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icona, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(testo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
          ]),
        ),
      );
}
