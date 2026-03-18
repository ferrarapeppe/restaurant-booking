import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

class OpeningHoursScreen extends StatefulWidget {
  const OpeningHoursScreen({super.key});
  @override
  State<OpeningHoursScreen> createState() => _OpeningHoursScreenState();
}

class _OpeningHoursScreenState extends State<OpeningHoursScreen> {
  static const String _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _hours = [];
  List<Map<String, dynamic>> _specialHours = [];
  bool _loading = true;

  static const _days = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('opening_hours')
          .select('*')
          .eq('restaurant_id', _restaurantId)
          .order('day_of_week');
      final regular = <Map<String, dynamic>>[];
      final special = <Map<String, dynamic>>[];
      for (final h in res) {
        if (h['special_date'] != null) {
          special.add(Map<String, dynamic>.from(h));
        } else {
          regular.add(Map<String, dynamic>.from(h));
        }
      }
      setState(() { _hours = regular; _specialHours = special; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    await _supabase.from('opening_hours').delete().eq('id', id);
    _loadData();
  }

  Future<void> _duplicate(Map<String, dynamic> h) async {
    await _supabase.from('opening_hours').insert({
      'restaurant_id': _restaurantId,
      'day_of_week': h['day_of_week'],
      'open_time': h['open_time'],
      'close_time': h['close_time'],
      'is_closed': h['is_closed'],
      'shift_name': h['shift_name'],
      'min_party_size': h['min_party_size'],
      'max_party_size': h['max_party_size'],
      'title': h['title'],
      'notes': h['notes'],
    });
    _loadData();
  }

  String _formatTime(String? t) => t?.substring(0, 5) ?? '--:--';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Orari di apertura', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D52)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Orari di Apertura',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Gestisci gli orari di apertura e aggiungi le impostazioni di gestione delle prenotazioni per orario di apertura.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                // Tabella orari
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          const Expanded(child: Text('Giorno', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                          const Expanded(child: Text('Orario', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                          const SizedBox(width: 100),
                        ]),
                      ),
                      const Divider(height: 1, color: AppColors.divider),
                      // Righe
                      ..._hours.asMap().entries.map((entry) {
                        final i = entry.key;
                        final h = entry.value;
                        final dayIdx = (h['day_of_week'] as int?) ?? 0;
                        final dayName = dayIdx < _days.length ? _days[dayIdx] : 'Giorno $dayIdx';
                        final isClosed = h['is_closed'] == true;
                        return Column(children: [
                          Container(
                            color: i % 2 == 1 ? AppColors.background.withOpacity(0.5) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(children: [
                              Expanded(child: Text(dayName,
                                  style: TextStyle(
                                    color: isClosed ? AppColors.textMuted : AppColors.textPrimary,
                                    fontSize: 15,
                                  ))),
                              Expanded(child: Text(
                                isClosed ? 'Chiuso' : '${_formatTime(h['open_time'])} - ${_formatTime(h['close_time'])}',
                                style: TextStyle(
                                  color: isClosed ? AppColors.textMuted : AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              )),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                  onPressed: () => _showForm(context, existing: h),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_box_outlined, size: 18, color: AppColors.textSecondary),
                                  onPressed: () => _duplicate(h),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
                                  onPressed: () => _delete(h['id']),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ]),
                            ]),
                          ),
                          if (i < _hours.length - 1) const Divider(height: 1, color: AppColors.divider),
                        ]);
                      }),
                      const Divider(height: 1, color: AppColors.divider),
                      // Aggiungi
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showForm(context),
                            icon: const Icon(Icons.add, color: AppColors.textPrimary, size: 18),
                            label: const Text('+ Aggiungi nuovo orario di apertura',
                                style: TextStyle(color: AppColors.textPrimary)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.divider),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Orari speciali
                const Text('Orari di apertura speciali',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: const [
                        Expanded(child: Text('Giorno', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                        Expanded(child: Text('Stato', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                        Expanded(child: Text('Orario', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                      ]),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    if (_specialHours.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nessun orario speciale', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      ..._specialHours.map((h) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Expanded(child: Text(h['special_date'] ?? '', style: const TextStyle(color: AppColors.textPrimary))),
                          Expanded(child: Text(h['is_closed'] == true ? 'Chiuso' : 'Aperto',
                              style: const TextStyle(color: AppColors.textSecondary))),
                          Expanded(child: Text(
                            h['is_closed'] == true ? '-' : '${_formatTime(h['open_time'])} - ${_formatTime(h['close_time'])}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          )),
                        ]),
                      )),
                    const Divider(height: 1, color: AppColors.divider),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showForm(context, isSpecial: true),
                          icon: const Icon(Icons.add, color: AppColors.textPrimary, size: 18),
                          label: const Text('+ Aggiungi orari speciali',
                              style: TextStyle(color: AppColors.textPrimary)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.divider),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  void _showForm(BuildContext context, {Map<String, dynamic>? existing, bool isSpecial = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _OpeningHoursForm(
        existing: existing,
        isSpecial: isSpecial,
        restaurantId: _restaurantId,
        onSaved: () { Navigator.pop(context); _loadData(); },
      ),
    );
  }
}

// ── Form ──────────────────────────────────────────────────────────────────────
class _OpeningHoursForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final bool isSpecial;
  final String restaurantId;
  final VoidCallback onSaved;
  const _OpeningHoursForm({this.existing, required this.isSpecial, required this.restaurantId, required this.onSaved});

  @override
  State<_OpeningHoursForm> createState() => _OpeningHoursFormState();
}

class _OpeningHoursFormState extends State<_OpeningHoursForm> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabCtrl;
  static const _days = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
  static const _timeSlots = [
    '00:00','00:30','01:00','01:30','02:00','08:00','08:30','09:00','09:30',
    '10:00','10:30','11:00','11:30','12:00','12:30','13:00','13:30','14:00',
    '14:30','15:00','15:30','16:00','16:30','17:00','17:30','18:00','18:30',
    '19:00','19:30','20:00','20:30','21:00','21:30','22:00','22:30','23:00','23:30',
  ];

  int _selectedDay = 0;
  String _openTime = '18:30';
  String _closeTime = '01:00';
  bool _isClosed = false;
  int _minParty = 2;
  int _maxParty = 15;
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    final e = widget.existing;
    if (e != null) {
      _selectedDay = (e['day_of_week'] as int?) ?? 0;
      _openTime = e['open_time']?.toString().substring(0, 5) ?? '18:30';
      _closeTime = e['close_time']?.toString().substring(0, 5) ?? '01:00';
      _isClosed = e['is_closed'] == true;
      _minParty = (e['min_party_size'] as int?) ?? 2;
      _maxParty = (e['max_party_size'] as int?) ?? 15;
      _titleCtrl.text = e['title'] ?? '';
      _notesCtrl.text = e['notes'] ?? '';
    }
  }

  @override
  void dispose() { _tabCtrl.dispose(); _titleCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  String _calcLastSlot() {
    final parts = _closeTime.split(':');
    int closeMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    closeMin -= 120; // durata default 2 ore
    if (closeMin < 0) closeMin += 24 * 60;
    final h = (closeMin ~/ 60) % 24;
    final m = closeMin % 60;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = {
        'restaurant_id': widget.restaurantId,
        'day_of_week': _selectedDay,
        'open_time': _openTime + ':00',
        'close_time': _closeTime + ':00',
        'is_closed': _isClosed,
        'min_party_size': _minParty,
        'max_party_size': _maxParty,
        'title': _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };
      if (widget.existing != null) {
        await _supabase.from('opening_hours').update(data).eq('id', widget.existing!['id']);
      } else {
        await _supabase.from('opening_hours').insert(data);
      }
      widget.onSaved();
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
    final dayName = _days[_selectedDay];
    final lastSlot = _calcLastSlot();
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) => Column(children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text(
              widget.existing != null ? 'Modifica orario  ' : 'Aggiungi orario  ',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(dayName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 18)),
          ]),
        ),
        TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFF2E7D52),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'GENERALE'), Tab(text: 'POSTI A SEDERE'), Tab(text: 'LIMITI'), Tab(text: 'FORM')],
        ),
        Expanded(
          child: TabBarView(controller: _tabCtrl, children: [
            // ── GENERALE ──
            ListView(controller: sc, padding: const EdgeInsets.all(16), children: [
              // Giorno
              _FormField(
                label: 'Giorno',
                child: DropdownButton<int>(
                  value: _selectedDay,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(_days[i]))),
                  onChanged: (v) => setState(() => _selectedDay = v!),
                ),
              ),
              const SizedBox(height: 12),
              // Chiuso toggle
              Row(children: [
                const Expanded(child: Text('Chiuso', style: TextStyle(color: AppColors.textPrimary, fontSize: 15))),
                Switch(value: _isClosed, onChanged: (v) => setState(() => _isClosed = v), activeColor: const Color(0xFF2E7D52)),
              ]),
              if (!_isClosed) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _FormField(
                    label: 'Apre alle',
                    child: DropdownButton<String>(
                      value: _timeSlots.contains(_openTime) ? _openTime : _timeSlots.first,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _openTime = v!),
                    ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _FormField(
                    label: 'Gli ospiti escono entro',
                    child: DropdownButton<String>(
                      value: _timeSlots.contains(_closeTime) ? _closeTime : _timeSlots.first,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _closeTime = v!),
                    ),
                  )),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Imposta quando apri e quando gli ultimi ospiti devono uscire. L\'ultimo slot di prenotazione viene calcolato automaticamente in base alla durata della prenotazione.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                // Ultimo slot
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('ULTIMO SLOT DI PRENOTAZIONE',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text(lastSlot, style: const TextStyle(color: Color(0xFF2E7D52), fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Gli ospiti che prenotano alle $lastSlot ceneranno per 2:00 e usciranno all\'orario di chiusura.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    // Barra visiva
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.85,
                        backgroundColor: Colors.red.withOpacity(0.4),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D52)),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_openTime, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      Text(lastSlot, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      Text(_closeTime, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                // Titolo
                _FormField(
                  label: 'Titolo',
                  child: TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  ),
                ),
                const Text(
                  'Un titolo opzionale mostrato sopra gli orari disponibili durante questo periodo nel flusso di prenotazione. Per esempio "Pranzo" o "Cena a Buffet"',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _FormField(
                  label: 'Note',
                  child: TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  ),
                ),
              ],
            ]),
            // ── POSTI A SEDERE ──
            ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Posti a sedere', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _FormField(
                label: 'Minimo persone per prenotazione',
                child: Row(children: [
                  Expanded(child: Text('$_minParty', style: const TextStyle(color: Colors.white, fontSize: 16))),
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54), onPressed: () => setState(() => _minParty = (_minParty - 1).clamp(1, 20))),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54), onPressed: () => setState(() => _minParty = (_minParty + 1).clamp(1, 20))),
                ]),
              ),
              const SizedBox(height: 12),
              _FormField(
                label: 'Massimo persone per prenotazione',
                child: Row(children: [
                  Expanded(child: Text('$_maxParty', style: const TextStyle(color: Colors.white, fontSize: 16))),
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54), onPressed: () => setState(() => _maxParty = (_maxParty - 1).clamp(1, 50))),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54), onPressed: () => setState(() => _maxParty = (_maxParty + 1).clamp(1, 50))),
                ]),
              ),
            ]),
            // ── LIMITI ──
            const Center(child: Text('Limiti — in costruzione', style: TextStyle(color: AppColors.textSecondary))),
            // ── FORM ──
            const Center(child: Text('Form — in costruzione', style: TextStyle(color: AppColors.textSecondary))),
          ]),
        ),
        // Bottoni
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D52),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Salva', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Annulla', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        child,
      ]),
    );
  }
}
