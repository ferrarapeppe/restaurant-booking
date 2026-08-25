// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

/// Esportazione dei clienti in un file di rubrica (vCard).
///
/// Serve a poter scrivere ai clienti da WhatsApp col telefono: il file si apre
/// sul cellulare e i contatti entrano in rubrica. WhatsApp riconosce un
/// contatto solo se il numero e' in formato internazionale, quindi chi non ce
/// l'ha viene escluso invece di finire in rubrica muto.
class EsportaRubrica {
  static const _idRistorante = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

  /// I contatti nascono col prefisso nel nome: cosi' non si confondono con la
  /// rubrica personale, si trovano tutti cercando "HIO" e un domani si
  /// cancellano in blocco.
  static const prefissoNome = 'HIO';

  /// Un numero utilizzabile ha il + e almeno dieci cifre.
  static bool numeroValido(String? telefono) {
    final t = (telefono ?? '').trim();
    if (!t.startsWith('+')) return false;
    return RegExp(r'\D').allMatches(t).length < t.length &&
        t.replaceAll(RegExp(r'\D'), '').length >= 10;
  }

  /// Nel formato vCard virgole, punti e virgola e barre rovesce vanno protetti,
  /// altrimenti spezzano il campo e il contatto arriva sbagliato.
  static String _protetto(String v) => v
      .replaceAll('\\', '\\\\')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;')
      .replaceAll('\n', '\\n');

  static String _nomeCompleto(Map<String, dynamic> g) {
    final nome = (g['first_name'] ?? '').toString().trim();
    final cognome = (g['surname'] ?? '').toString().trim();
    final unito = '$nome $cognome'.trim();
    if (unito.isNotEmpty) return unito;
    return (g['name'] ?? '').toString().trim();
  }

  static String _scheda(Map<String, dynamic> g) {
    final nome = (g['first_name'] ?? '').toString().trim();
    final cognome = (g['surname'] ?? '').toString().trim();
    final completo = _nomeCompleto(g);
    final email = (g['email'] ?? '').toString().trim();
    final telefono = (g['phone'] ?? '').toString().trim();
    final visite = (g['visits_count'] as int?) ?? 0;
    final tag = [
      for (final t in (g['tags'] as List? ?? const [])) t.toString().trim()
    ].where((t) => t.isNotEmpty).toList();

    final note = [
      'Cliente Hio Oriental Bar',
      if (visite > 0) '$visite ${visite == 1 ? 'visita' : 'visite'}',
      if (tag.isNotEmpty) 'Tag: ${tag.join(', ')}',
    ].join(' — ');

    final righe = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      // Cognome;Nome;;;  — il prefisso sta solo nel nome visualizzato
      'N:${_protetto(cognome)};${_protetto(nome)};;;',
      'FN:${_protetto('$prefissoNome $completo')}',
      if (telefono.isNotEmpty) 'TEL;TYPE=CELL:${_protetto(telefono)}',
      if (email.isNotEmpty) 'EMAIL;TYPE=INTERNET:${_protetto(email)}',
      'ORG:${_protetto('Hio Oriental Bar')}',
      'NOTE:${_protetto(note)}',
      'END:VCARD',
    ];
    return righe.join('\r\n');
  }

  /// Tag di chi e' arrivato dall'agenda del telefono invece che da una
  /// prenotazione: sul telefono c'e' gia', riesportarlo creerebbe un doppione.
  static const tagRubrica = 'rubrica';

  /// Scarica il file. Restituisce quanti contatti sono finiti dentro e quanti
  /// sono stati scartati perche' senza numero utilizzabile o gia' in rubrica.
  static Future<({int esportati, int scartati, int giaInRubrica, List<String> ids})> scarica({
    DateTime? soloDopo,
    bool escludiGiaInRubrica = true,
  }) async {
    var query = Supabase.instance.client
        .from('guests')
        .select('id, first_name, surname, name, email, phone, visits_count, tags, created_at')
        .eq('restaurant_id', _idRistorante);

    if (soloDopo != null) {
      query = query.gte('created_at', soloDopo.toIso8601String());
    }

    final righe = await query.order('surname');

    final schede = <String>[];
    final ids = <String>[];
    var scartati = 0;
    var giaInRubrica = 0;
    for (final r in righe) {
      final g = Map<String, dynamic>.from(r as Map);
      final tag = [
        for (final t in (g['tags'] as List? ?? const [])) t.toString().trim()
      ];
      if (escludiGiaInRubrica && tag.contains(tagRubrica)) {
        giaInRubrica++;
        continue;
      }
      if (!numeroValido(g['phone']?.toString())) {
        scartati++;
        continue;
      }
      if (_nomeCompleto(g).isEmpty) {
        scartati++;
        continue;
      }
      schede.add(_scheda(g));
      ids.add(g['id'].toString());
    }

    if (schede.isNotEmpty) {
      final contenuto = '${schede.join('\r\n')}\r\n';
      // Il BOM aiuta iOS a leggere gli accenti nei cognomi.
      // Serve un Uint8List e non una semplice lista di interi: al browser una
      // lista arriva come array JavaScript e finisce nel file come testo
      // "239,187,191,66,..." invece che come byte.
      final byte = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(contenuto)]);
      final blob = html.Blob([byte], 'text/vcard;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final oggi = DateFormat('yyyy-MM-dd').format(DateTime.now());
      html.AnchorElement(href: url)
        ..setAttribute('download', 'rubrica-hio-$oggi.vcf')
        ..click();
      html.Url.revokeObjectUrl(url);
    }

    return (
      esportati: schede.length,
      scartati: scartati,
      giaInRubrica: giaInRubrica,
      ids: ids,
    );
  }

  /// Segna i clienti come gia' presenti nell'agenda del telefono.
  ///
  /// Va chiamata **dopo** l'importazione sul telefono, non prima: marcarli in
  /// anticipo li escluderebbe per sempre dalle esportazioni successive anche
  /// se l'importazione non fosse mai avvenuta.
  static Future<int> segnaComeImportati(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final n = await Supabase.instance.client
        .rpc('segna_in_rubrica', params: {'ids': ids});
    return (n as num?)?.toInt() ?? 0;
  }
}

/// Finestra che chiede cosa esportare e poi scarica.
class SchedaEsportaRubrica extends StatefulWidget {
  const SchedaEsportaRubrica({super.key});

  @override
  State<SchedaEsportaRubrica> createState() => _SchedaEsportaRubricaState();
}

class _SchedaEsportaRubricaState extends State<SchedaEsportaRubrica> {
  bool _soloNuovi = false;
  bool _escludiRubrica = true;
  DateTime _dal = DateTime.now().subtract(const Duration(days: 30));
  bool _inCorso = false;
  String? _errore;

  // Dopo lo scarico la scheda non si chiude: resta aperta per farsi confermare
  // che l'importazione sul telefono e' davvero avvenuta.
  List<String>? _scaricati;
  int _quantiScaricati = 0;
  int _quantiScartati = 0;
  int _quantiGiaInRubrica = 0;

  Future<void> _esegui() async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });
    try {
      final esito = await EsportaRubrica.scarica(
        soloDopo: _soloNuovi ? _dal : null,
        escludiGiaInRubrica: _escludiRubrica,
      );
      if (!mounted) return;
      if (esito.esportati == 0) {
        setState(() {
          _errore = 'Nessun contatto da esportare: sono già tutti in rubrica.';
          _inCorso = false;
        });
        return;
      }
      setState(() {
        _scaricati = esito.ids;
        _quantiScaricati = esito.esportati;
        _quantiScartati = esito.scartati;
        _quantiGiaInRubrica = esito.giaInRubrica;
        _inCorso = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.toString().replaceFirst('Exception: ', '');
        _inCorso = false;
      });
    }
  }

  Future<void> _segna() async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });
    try {
      final n = await EsportaRubrica.segnaComeImportati(_scaricati ?? const []);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.statoConfermato,
        duration: const Duration(seconds: 4),
        content: Text('$n contatti segnati come già in rubrica: '
            'non verranno più riproposti.'),
      ));
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          const Text('Esporta in rubrica',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_scaricati != null) ..._passoConferma() else ...[
          const Text(
            'Scarica un file da aprire sul telefono: i clienti entrano in rubrica '
            'col nome preceduto da "HIO", così non si confondono con i tuoi contatti '
            'e li ritrovi tutti insieme.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.statoConfermato,
            value: _soloNuovi,
            onChanged: (v) => setState(() => _soloNuovi = v),
            title: const Text('Solo i clienti nuovi',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: const Text('Per non riscaricare ogni volta tutta la rubrica',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.statoConfermato,
            value: _escludiRubrica,
            onChanged: (v) => setState(() => _escludiRubrica = v),
            title: const Text('Salta chi è già in rubrica',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            subtitle: const Text('Riesportarli creerebbe doppioni sul telefono',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          if (_soloNuovi)
            OutlinedButton.icon(
              onPressed: () async {
                final scelta = await showDatePicker(
                  context: context,
                  initialDate: _dal,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  locale: const Locale('it', 'IT'),
                );
                if (scelta != null) setState(() => _dal = scelta);
              },
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('Aggiunti dal ${DateFormat('d MMMM yyyy', 'it_IT').format(_dal)}'),
            ),
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
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _inCorso ? null : _esegui,
              icon: _inCorso
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_outlined, size: 18),
              label: const Text('Scarica il file'),
            ),
          ),
          ],
        ]),
      ),
    );
  }

  /// Secondo passo: il file e' stato scaricato, ora si aspetta che l'utente
  /// confermi di averlo importato davvero sul telefono.
  List<Widget> _passoConferma() {
    final esclusi = [
      if (_quantiScartati > 0) '$_quantiScartati senza numero utilizzabile',
      if (_quantiGiaInRubrica > 0) '$_quantiGiaInRubrica già in rubrica',
    ];

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.statoConfermatoSfondo,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_outline, color: AppColors.statoConfermato, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_quantiScaricati contatti scaricati',
                  style: const TextStyle(
                      color: AppColors.statoConfermato,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              if (esclusi.isNotEmpty)
                Text('Esclusi: ${esclusi.join(', ')}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      const Text('Ora importali sul telefono',
          style: TextStyle(
              color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text(
        'Dal computer apri icloud.com/contacts e scegli "Importa vCard": '
        'il telefono si aggiorna da solo. Torna qui solo quando è fatto.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.goldLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: const Text(
          'Conferma solo dopo aver importato davvero. Segnandoli prima, questi '
          'nomi non verrebbero più riproposti e resterebbero fuori dalla rubrica.',
          style: TextStyle(color: AppColors.goldDark, fontSize: 12, height: 1.4),
        ),
      ),
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
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.statoConfermato,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _inCorso ? null : _segna,
          icon: _inCorso
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.done_all, size: 18),
          label: const Text('Fatto, segnali come importati'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: _inCorso ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Non ora — li importo più tardi'),
        ),
      ),
    ];
  }
}
