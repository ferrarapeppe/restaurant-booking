import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/core/auth/accesso.dart';

/// Gestione dei membri dello staff e dei loro permessi.
///
/// Le modifiche non toccano il database direttamente: passano dalla funzione
/// `manage-staff`, che e' l'unica a poter creare o cancellare un accesso.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<Map<String, dynamic>> _membri = [];
  bool _inCaricamento = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<Map<String, dynamic>> _chiama(Map<String, dynamic> corpo) async {
    final res = await Supabase.instance.client.functions.invoke('manage-staff', body: corpo);
    final dati = res.data;
    if (dati is Map && dati['error'] != null) throw Exception(dati['error'].toString());
    return dati is Map ? Map<String, dynamic>.from(dati) : <String, dynamic>{};
  }

  Future<void> _carica() async {
    setState(() {
      _inCaricamento = true;
      _errore = null;
    });
    try {
      final r = await _chiama({'azione': 'elenco'});
      final lista = (r['membri'] as List? ?? const []);
      if (!mounted) return;
      setState(() {
        _membri = [for (final m in lista) Map<String, dynamic>.from(m as Map)];
        _inCaricamento = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = _leggibile(e);
        _inCaricamento = false;
      });
    }
  }

  String _leggibile(Object e) =>
      e.toString().replaceFirst('Exception: ', '').replaceFirst('FunctionException: ', '');

  void _avviso(String testo, {bool errore = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(testo),
      backgroundColor: errore ? AppColors.accent : AppColors.statoConfermato,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _apriScheda({Map<String, dynamic>? membro}) async {
    final salvato = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SchedaMembro(membro: membro, chiama: _chiama),
    );
    if (salvato == true) {
      _avviso(membro == null ? 'Membro creato.' : 'Modifiche salvate.');
      await _carica();
      // Se ho modificato me stesso, i miei permessi vanno riletti subito.
      await statoAccesso.ricarica();
    }
  }

  Future<void> _elimina(Map<String, dynamic> membro) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminare il membro?'),
        content: Text(
          '${membro['email']} non potrà più entrare. '
          'L\'operazione non si annulla.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    try {
      await _chiama({'azione': 'elimina', 'id': membro['id']});
      _avviso('Membro eliminato.');
      await _carica();
    } catch (e) {
      _avviso(_leggibile(e), errore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amministratore = statoAccesso.profilo?.eAmministratore ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Team', style: TextStyle(color: AppColors.textPrimary)),
      ),
      floatingActionButton: amministratore
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              onPressed: () => _apriScheda(),
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: const Text('Nuovo membro', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: !amministratore
          ? const _Messaggio(
              icona: Icons.lock_outline,
              titolo: 'Riservato agli amministratori',
              testo: 'Solo un amministratore può gestire i membri del team.',
            )
          : _inCaricamento
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _errore != null
                  ? _Messaggio(
                      icona: Icons.error_outline,
                      titolo: 'Elenco non caricato',
                      testo: _errore!,
                      azione: OutlinedButton(onPressed: _carica, child: const Text('Riprova')),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      children: [
                        const Text(
                          'Ogni membro entra con la propria email e vede solo le sezioni '
                          'che gli abiliti. Un amministratore vede e fa tutto.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        for (final m in _membri) ...[
                          _RigaMembro(
                            membro: m,
                            sonoIo: m['id'] == statoAccesso.profilo?.id,
                            onModifica: () => _apriScheda(membro: m),
                            onElimina: () => _elimina(m),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_membri.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Text('Nessun membro.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                      ],
                    ),
    );
  }
}

class _Messaggio extends StatelessWidget {
  final IconData icona;
  final String titolo, testo;
  final Widget? azione;
  const _Messaggio({required this.icona, required this.titolo, required this.testo, this.azione});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icona, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(titolo,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(testo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
            if (azione != null) ...[const SizedBox(height: 18), azione!],
          ]),
        ),
      );
}

class _RigaMembro extends StatelessWidget {
  final Map<String, dynamic> membro;
  final bool sonoIo;
  final VoidCallback onModifica, onElimina;
  const _RigaMembro({
    required this.membro,
    required this.sonoIo,
    required this.onModifica,
    required this.onElimina,
  });

  @override
  Widget build(BuildContext context) {
    final amministratore = membro['role'] == 'admin';
    final attivo = membro['active'] != false;
    final sezioni = (membro['sections'] as List? ?? const []).length;
    final nome = (membro['full_name'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: amministratore ? AppColors.accentLight : AppColors.goldLight,
          child: Icon(amministratore ? Icons.shield_outlined : Icons.person_outline,
              size: 20, color: amministratore ? AppColors.accent : AppColors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(nome.isEmpty ? membro['email'].toString() : nome,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              if (sonoIo) ...[
                const SizedBox(width: 6),
                const Text('(tu)', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ]),
            const SizedBox(height: 2),
            Text(
              amministratore
                  ? 'Amministratore — tutte le sezioni'
                  : '$sezioni ${sezioni == 1 ? 'sezione' : 'sezioni'} abilitate',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            if (!attivo) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.accentLight, borderRadius: BorderRadius.circular(10)),
                child: const Text('Disattivato',
                    style: TextStyle(
                        color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
          onPressed: onModifica,
        ),
        if (!sonoIo)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.accent),
            onPressed: onElimina,
          ),
      ]),
    );
  }
}

// ── Scheda di creazione e modifica ───────────────────────────────────────────

class _SchedaMembro extends StatefulWidget {
  final Map<String, dynamic>? membro;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) chiama;
  const _SchedaMembro({required this.membro, required this.chiama});

  @override
  State<_SchedaMembro> createState() => _SchedaMembroState();
}

class _SchedaMembroState extends State<_SchedaMembro> {
  final _modulo = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _nome;
  final _password = TextEditingController();

  late String _ruolo;
  late Set<String> _sezioni;
  late bool _attivo;
  bool _inCorso = false;
  String? _errore;

  bool get _nuovo => widget.membro == null;

  @override
  void initState() {
    super.initState();
    final m = widget.membro;
    _email = TextEditingController(text: (m?['email'] ?? '').toString());
    _nome = TextEditingController(text: (m?['full_name'] ?? '').toString());
    _ruolo = (m?['role'] ?? 'staff').toString();
    _sezioni = {for (final s in (m?['sections'] as List? ?? const [])) s.toString()};
    _attivo = m?['active'] != false;
  }

  @override
  void dispose() {
    _email.dispose();
    _nome.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    if (!_modulo.currentState!.validate() || _inCorso) return;
    if (_ruolo == 'staff' && _sezioni.isEmpty) {
      setState(() => _errore = 'Abilita almeno una sezione, oppure rendilo amministratore.');
      return;
    }
    setState(() {
      _inCorso = true;
      _errore = null;
    });
    try {
      if (_nuovo) {
        await widget.chiama({
          'azione': 'crea',
          'email': _email.text.trim(),
          'password': _password.text,
          'nome': _nome.text.trim(),
          'ruolo': _ruolo,
          'sezioni': _sezioni.toList(),
        });
      } else {
        await widget.chiama({
          'azione': 'modifica',
          'id': widget.membro!['id'],
          'nome': _nome.text.trim(),
          'ruolo': _ruolo,
          'sezioni': _sezioni.toList(),
          'attivo': _attivo,
          if (_password.text.isNotEmpty) 'password': _password.text,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.toString().replaceFirst('Exception: ', '');
        _inCorso = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amministratore = _ruolo == 'admin';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Form(
            key: _modulo,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 16),
              Text(_nuovo ? 'Nuovo membro' : 'Modifica membro',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                enabled: _nuovo, // l'email identifica l'accesso: non si cambia
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Email non valida' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nome,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Nome e cognome'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: _nuovo ? 'Password' : 'Nuova password (opzionale)',
                  helperText: 'Almeno 8 caratteri. Comunicala tu al membro.',
                ),
                validator: (v) {
                  if (_nuovo && (v == null || v.length < 8)) return 'Almeno 8 caratteri';
                  if (!_nuovo && v != null && v.isNotEmpty && v.length < 8) {
                    return 'Almeno 8 caratteri';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const Text('Ruolo',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'staff', label: Text('Staff')),
                  ButtonSegment(value: 'admin', label: Text('Amministratore')),
                ],
                selected: {_ruolo},
                onSelectionChanged: (s) => setState(() => _ruolo = s.first),
              ),
              const SizedBox(height: 18),
              const Text('Sezioni abilitate',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                amministratore
                    ? "L'amministratore vede tutte le sezioni: la scelta qui sotto non si applica."
                    : 'Il membro vedrà solo le sezioni che spunti.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Opacity(
                opacity: amministratore ? 0.45 : 1,
                child: IgnorePointer(
                  ignoring: amministratore,
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in sezioniApp)
                      FilterChip(
                        label: Text(s.etichetta),
                        selected: amministratore || _sezioni.contains(s.chiave),
                        onSelected: (v) => setState(() {
                          v ? _sezioni.add(s.chiave) : _sezioni.remove(s.chiave);
                        }),
                        selectedColor: AppColors.accentLight,
                        checkmarkColor: AppColors.accent,
                      ),
                  ]),
                ),
              ),
              if (!_nuovo) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.statoConfermato,
                  title: const Text('Accesso attivo',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  subtitle: const Text('Se spento, il membro non può entrare.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  value: _attivo,
                  onChanged: (v) => setState(() => _attivo = v),
                ),
              ],
              if (_errore != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                      color: AppColors.accentLight, borderRadius: BorderRadius.circular(8)),
                  child: Text(_errore!,
                      style: const TextStyle(color: AppColors.accent, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _inCorso ? null : _salva,
                  child: _inCorso
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_nuovo ? 'Crea membro' : 'Salva modifiche'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
