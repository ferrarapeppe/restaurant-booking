import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/contenuto_centrato.dart';
import 'package:restaurant_booking/shared/widgets/pulsante_barra.dart';

/// Gli avvisi allo staff su Telegram.
///
/// Il numero di telefono non c'entra: un bot non può scrivere per primo a
/// nessuno, è una regola di Telegram contro lo spam. Chi vuole gli avvisi
/// deve aprire il bot — o mettere il bot in un gruppo — e scrivergli una
/// volta. Da quel momento la chat è raggiungibile per sempre.
///
/// Per questo la schermata non chiede un numero ma va a *cercare* le chat che
/// hanno scritto al bot di recente, e ci si sceglie la propria.
class TelegramScreen extends StatefulWidget {
  const TelegramScreen({super.key});

  @override
  State<TelegramScreen> createState() => _TelegramScreenState();
}

class _TelegramScreenState extends State<TelegramScreen> {
  static const _idRistorante = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  final _supabase = Supabase.instance.client;

  /// I destinatari salvati: `{id, nome}`.
  List<Map<String, dynamic>> _chats = [];

  /// Quali avvisi partono. Assente vuol dire acceso: chi accende Telegram lo
  /// fa per essere avvisato, non per configurare un elenco di eccezioni.
  Map<String, dynamic> _eventi = {};

  bool _caricamento = true, _salvataggio = false, _ricerca = false;

  static const _tipiAvviso = <(String, String, String)>[
    ('prenotazione', 'Nuova prenotazione dal sito',
        'Nome, giorno, ora, persone, area, turno e note.'),
    ('annullamento', 'Annullamenti e no-show',
        'Quando una prenotazione salta e il tavolo torna libero.'),
    ('messaggio', 'Messaggi dei clienti',
        'Quello che scrivono dalla pagina della loro prenotazione.'),
    ('riepilogo', 'Riepilogo della giornata',
        'Coperti per turno e prenotazioni da approvare.'),
  ];

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final r = await _supabase
          .from('restaurants')
          .select('settings')
          .eq('id', _idRistorante)
          .single();
      final tg = (r['settings'] as Map?)?['telegram'] as Map? ?? {};
      setState(() {
        _chats = [
          for (final c in (tg['chats'] as List? ?? const []))
            Map<String, dynamic>.from(c as Map)
        ];
        _eventi = Map<String, dynamic>.from(tg['eventi'] as Map? ?? {});
        _caricamento = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _caricamento = false);
        _avviso('Impostazioni non caricate: $e', errore: true);
      }
    }
  }

  Future<void> _salva() async {
    setState(() => _salvataggio = true);
    try {
      // Si riscrive solo il ramo `telegram`: `settings` tiene dentro anche
      // il logo e altre cose che non c'entrano niente con questa schermata.
      final r = await _supabase
          .from('restaurants')
          .select('settings')
          .eq('id', _idRistorante)
          .single();
      final settings = Map<String, dynamic>.from(r['settings'] as Map? ?? {});
      settings['telegram'] = {'chats': _chats, 'eventi': _eventi};
      await _supabase
          .from('restaurants')
          .update({'settings': settings}).eq('id', _idRistorante);
      if (mounted) _avviso('Impostazioni salvate.');
    } catch (e) {
      if (mounted) _avviso('Non salvate: $e', errore: true);
    } finally {
      if (mounted) setState(() => _salvataggio = false);
    }
  }

  Future<void> _cerca() async {
    setState(() => _ricerca = true);
    try {
      final r = await _supabase.functions
          .invoke('telegram', body: {'azione': 'chat-trovate'});
      final dati = r.data as Map?;
      if (dati?['error'] != null) {
        _avviso(dati!['error'].toString(), errore: true);
        return;
      }
      final trovate = [
        for (final c in (dati?['chats'] as List? ?? const []))
          Map<String, dynamic>.from(c as Map)
      ];
      if (!mounted) return;
      if (trovate.isEmpty) {
        _avviso(
            'Nessuna chat trovata. Nel gruppo scrivi /start@ seguito dal nome '
            'del bot: un messaggio normale il bot non lo vede.',
            errore: true);
        return;
      }
      _scegli(trovate);
    } catch (e) {
      if (mounted) _avviso('Ricerca non riuscita: $e', errore: true);
    } finally {
      if (mounted) setState(() => _ricerca = false);
    }
  }

  void _scegli(List<Map<String, dynamic>> trovate) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Chat trovate',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          for (final c in trovate)
            ListTile(
              leading: Icon(
                  c['tipo'] == 'private'
                      ? Icons.person_outline
                      : Icons.groups_outlined,
                  color: AppColors.textSecondary),
              title: Text(c['nome']?.toString() ?? c['id'].toString(),
                  style: const TextStyle(color: AppColors.textPrimary)),
              subtitle: Text(
                  c['tipo'] == 'private' ? 'Chat privata' : 'Gruppo',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              trailing: _giaPresente(c['id'].toString())
                  ? const Icon(Icons.check, color: AppColors.badgeGreen)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (_giaPresente(c['id'].toString())) return;
                setState(() => _chats.add({
                      'id': c['id'].toString(),
                      'nome': c['nome']?.toString() ?? c['id'].toString(),
                    }));
                _salva();
              },
            ),
        ]),
      ),
    );
  }

  bool _giaPresente(String id) => _chats.any((c) => c['id'].toString() == id);

  Future<void> _prova(String chatId) async {
    try {
      final r = await _supabase.functions
          .invoke('telegram', body: {'azione': 'prova', 'chat_id': chatId});
      final dati = r.data as Map?;
      if (!mounted) return;
      if (dati?['error'] != null) {
        _avviso(dati!['error'].toString(), errore: true);
      } else {
        _avviso('Messaggio di prova inviato.');
      }
    } catch (e) {
      if (mounted) _avviso('Invio non riuscito: $e', errore: true);
    }
  }

  void _avviso(String testo, {bool errore = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(testo),
      backgroundColor: errore ? AppColors.accent : AppColors.badgeGreen,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: const PulsanteBarra(),
        title: const Text('Avvisi su Telegram',
            style:
                TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
      ),
      body: _caricamento
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : ContenutoCentrato(
              larghezzaMassima: 820,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _Spiegazione(),
                const SizedBox(height: 20),
                const _Titolo('Chi riceve gli avvisi'),
                const SizedBox(height: 8),
                if (_chats.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('Nessun destinatario: gli avvisi non partono.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 14)),
                  ),
                for (final c in _chats)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(children: [
                      const Icon(Icons.send_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['nome']?.toString() ?? '',
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            Text(c['id'].toString(),
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _prova(c['id'].toString()),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.goldDark),
                        child: const Text('Prova'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.accent, size: 20),
                        tooltip: 'Togli',
                        onPressed: () {
                          setState(() => _chats.removeWhere(
                              (x) => x['id'] == c['id']));
                          _salva();
                        },
                      ),
                    ]),
                  ),
                const SizedBox(height: 4),
                ElevatedButton.icon(
                  onPressed: _ricerca ? null : _cerca,
                  icon: _ricerca
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search, size: 18),
                  label: const Text('Cerca le chat del bot'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                const _Titolo('Quali avvisi'),
                const SizedBox(height: 4),
                for (final t in _tipiAvviso)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _eventi[t.$1] != false,
                    onChanged: (v) {
                      setState(() => _eventi[t.$1] = v);
                      _salva();
                    },
                    activeColor: AppColors.accent,
                    title: Text(t.$2,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(t.$3,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ),
                const SizedBox(height: 24),
                if (_salvataggio)
                  const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent)),
                const SizedBox(height: 24),
              ]),
            ),
    );
  }
}

class _Spiegazione extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.goldLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Come si aggiunge una persona',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Telegram non permette a un bot di scrivere per primo a un '
              'numero di telefono. Quindi la chat deve farsi trovare:\n\n'
              '1. nel gruppo dove hai messo il bot scrivi «/start@» seguito '
              'dal nome del bot, per esempio /start@HioAvvisiBot. Un '
              'messaggio normale non basta: nei gruppi il bot vede solo i '
              'comandi rivolti a lui;\n'
              '2. tocca «Cerca le chat del bot» qui sotto;\n'
              '3. scegli la chat dall\'elenco, poi «Prova».\n\n'
              'Per una singola persona basta invece che apra il bot e prema '
              'Avvia. Per togliere un destinatario, il cestino.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.55),
            ),
          ],
        ),
      );
}

class _Titolo extends StatelessWidget {
  final String testo;
  const _Titolo(this.testo);
  @override
  Widget build(BuildContext context) => Text(testo,
      style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.bold));
}
