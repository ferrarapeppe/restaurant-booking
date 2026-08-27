import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/contenuto_centrato.dart';

class RestaurantProfileScreen extends StatefulWidget {
  const RestaurantProfileScreen({super.key});
  @override
  State<RestaurantProfileScreen> createState() => _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  static const String _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();

  /// Da quando il modulo pubblico accetta prenotazioni. Vuota = da subito.
  /// Vive nella colonna `settings` del ristorante, che era libera.
  DateTime? _prenotazioniDal;
  Map<String, dynamic> _altreImpostazioni = {};

  /// Indirizzo del logo caricato, anche lui dentro `settings`.
  ///
  /// Non si salva l'immagine nel database ma solo il suo indirizzo: la
  /// colonna `settings` viene letta a ogni apertura del calendario, e
  /// infilarci dentro un'immagine vorrebbe dire riscaricarla ogni volta.
  String? _logoUrl;
  bool _caricandoLogo = false;

  /// Il contenitore dei file su Supabase. Va creato una volta sola con
  /// `supabase/manutenzione/08_contenitore_loghi.sql`.
  static const _contenitore = 'loghi';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _addressCtrl.dispose(); _cityCtrl.dispose();
    _phoneCtrl.dispose(); _emailCtrl.dispose(); _websiteCtrl.dispose();
    _rulesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('restaurants')
          .select('*')
          .eq('id', _restaurantId)
          .single();
      _nameCtrl.text = res['name'] ?? '';
      _addressCtrl.text = res['address'] ?? '';
      _cityCtrl.text = res['city'] ?? '';
      _phoneCtrl.text = res['phone'] ?? '';
      _emailCtrl.text = res['email'] ?? '';
      _websiteCtrl.text = res['website'] ?? '';
      _rulesCtrl.text = res['booking_rules'] ?? '';
      final s = res['settings'];
      if (s is Map) {
        _altreImpostazioni = Map<String, dynamic>.from(s);
        _prenotazioniDal = DateTime.tryParse((s['prenotazioni_dal'] ?? '').toString());
        final l = (s['logo_url'] ?? '').toString();
        _logoUrl = l.isEmpty ? null : l;
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Sceglie un'immagine, la carica e la salva subito nel profilo.
  ///
  /// Il salvataggio è immediato e non aspetta il pulsante Salva: un logo
  /// caricato che sparisce uscendo dalla schermata sarebbe una sorpresa
  /// sgradevole, e chi lo cambia lo fa una volta ogni tanto.
  Future<void> _cambiaLogo() async {
    final scelta = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (scelta == null) return;

    setState(() => _caricandoLogo = true);
    try {
      final byte = await scelta.readAsBytes();
      final estensione = scelta.name.contains('.')
          ? scelta.name.split('.').last.toLowerCase()
          : 'png';
      // Il nome cambia a ogni caricamento: con un nome fisso le cache dei
      // browser continuerebbero a mostrare il logo vecchio.
      final nome = '$_restaurantId/logo-'
          '${DateTime.now().millisecondsSinceEpoch}.$estensione';

      await _supabase.storage.from(_contenitore).uploadBinary(
            nome,
            byte,
            fileOptions: FileOptions(contentType: scelta.mimeType, upsert: true),
          );
      final url = _supabase.storage.from(_contenitore).getPublicUrl(nome);

      await _supabase.from('restaurants').update({
        'settings': {..._altreImpostazioni, 'logo_url': url},
      }).eq('id', _restaurantId);

      if (!mounted) return;
      setState(() {
        _logoUrl = url;
        _altreImpostazioni = {..._altreImpostazioni, 'logo_url': url};
        _caricandoLogo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Logo aggiornato'),
        backgroundColor: AppColors.badgeGreen,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _caricandoLogo = false);
      // "Bucket not found" da solo non dice a nessuno cosa fare.
      final manca = e.toString().toLowerCase().contains('not found') ||
          e.toString().contains('404');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(manca
            ? 'Manca il contenitore dei loghi su Supabase: va creato una volta '
                'sola con manutenzione/08_contenitore_loghi.sql'
            : 'Caricamento non riuscito: $e'),
        backgroundColor: AppColors.accent,
      ));
    }
  }

  Future<void> _togliLogo() async {
    setState(() => _caricandoLogo = true);
    try {
      await _supabase.from('restaurants').update({
        'settings': {..._altreImpostazioni, 'logo_url': null},
      }).eq('id', _restaurantId);
      if (!mounted) return;
      setState(() {
        _logoUrl = null;
        _altreImpostazioni = {..._altreImpostazioni, 'logo_url': null};
        _caricandoLogo = false;
      });
    } catch (_) {
      if (mounted) setState(() => _caricandoLogo = false);
    }
  }

  Future<void> _scegliData() async {
    final oggi = DateTime.now();
    final scelta = await showDatePicker(
      context: context,
      initialDate: _prenotazioniDal ?? oggi,
      firstDate: DateTime(oggi.year - 1),
      lastDate: DateTime(oggi.year + 3),
      locale: const Locale('it', 'IT'),
    );
    if (scelta != null) setState(() => _prenotazioniDal = scelta);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _supabase.from('restaurants').update({
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'booking_rules': _rulesCtrl.text.trim(),
        // Le altre chiavi di settings vanno riscritte, altrimenti si perdono
        'settings': {
          ..._altreImpostazioni,
          if (_prenotazioniDal != null) 'prenotazioni_dal': _iso(_prenotazioniDal!) else 'prenotazioni_dal': null,
          'logo_url': _logoUrl,
        },
      }).eq('id', _restaurantId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo salvato'), backgroundColor: AppColors.badgeGreen),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profilo ristorante',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2))
                : const Text('Salva', style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ContenutoCentrato(larghezzaMassima: 820,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar ristorante
                Center(
                  child: Column(children: [
                    Container(
                      width: 100, height: 100,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        // Fondo chiaro quando c'è un'immagine: molti loghi
                        // hanno lo sfondo trasparente e sul rosso pieno
                        // sparirebbero.
                        color: _logoUrl == null ? AppColors.accent : AppColors.surface,
                        borderRadius: BorderRadius.circular(50),
                        border: _logoUrl == null
                            ? null
                            : Border.all(color: AppColors.divider),
                      ),
                      child: _caricandoLogo
                          ? const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.accent))
                          : _logoUrl == null
                              ? const Center(
                                  child: Text('HIO',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold)),
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Image.network(
                                    _logoUrl!,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_outlined,
                                          color: AppColors.textMuted),
                                    ),
                                  ),
                                ),
                    ),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TextButton.icon(
                        onPressed: _caricandoLogo ? null : _cambiaLogo,
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: Text(_logoUrl == null ? 'Carica il logo' : 'Cambia logo'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary),
                      ),
                      if (_logoUrl != null && !_caricandoLogo)
                        TextButton.icon(
                          onPressed: _togliLogo,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Togli'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.accent),
                        ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Informazioni generali'),
                const SizedBox(height: 12),
                _ProfileField(label: 'Nome ristorante', controller: _nameCtrl, icon: Icons.restaurant_outlined),
                const SizedBox(height: 10),
                _ProfileField(label: 'Indirizzo', controller: _addressCtrl, icon: Icons.location_on_outlined),
                const SizedBox(height: 10),
                _ProfileField(label: 'Città', controller: _cityCtrl, icon: Icons.location_city_outlined),
                const SizedBox(height: 10),
                _ProfileField(label: 'Telefono', controller: _phoneCtrl, icon: Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 10),
                _ProfileField(label: 'Email', controller: _emailCtrl, icon: Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _ProfileField(label: 'Sito web', controller: _websiteCtrl, icon: Icons.language_outlined, type: TextInputType.url),
                const SizedBox(height: 24),
                const _SectionTitle('Apertura delle prenotazioni online'),
                const SizedBox(height: 8),
                const Text(
                  'Prima di questa data il modulo non accetta prenotazioni: nel calendario '
                  'i giorni precedenti restano spenti. Lascia vuoto per accettare da subito.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _scegliData,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(children: [
                      const Icon(Icons.event_available_outlined, size: 20, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _prenotazioniDal == null
                              ? 'Nessuna data: si prenota da subito'
                              : 'Si prenota a partire dal ${_iso(_prenotazioniDal!)}',
                          style: TextStyle(
                            color: _prenotazioniDal == null ? AppColors.textMuted : AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (_prenotazioniDal != null)
                        IconButton(
                          tooltip: 'Togli la limitazione',
                          icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                          onPressed: () => setState(() => _prenotazioniDal = null),
                        ),
                      const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Regole di prenotazione'),
                const SizedBox(height: 8),
                const Text(
                  'Questo testo viene mostrato agli ospiti durante la prenotazione online.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: TextField(
                    controller: _rulesCtrl,
                    maxLines: 5,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Es: È possibile prenotare tavoli solo per cenare...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Bottone salva
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Salva profilo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            )),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
  );
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? type;
  const _ProfileField({required this.label, required this.controller, required this.icon, this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            TextField(
              controller: controller,
              keyboardType: type,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
