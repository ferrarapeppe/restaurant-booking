import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:restaurant_booking/data/models/table_model.dart';
import 'package:restaurant_booking/data/repositories/booking_repository.dart';
import 'package:restaurant_booking/data/repositories/guest_repository.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';
import 'package:restaurant_booking/core/providers/table_providers.dart';
import 'package:restaurant_booking/core/providers/guest_providers.dart';

class NewBookingScreen extends ConsumerStatefulWidget {
  const NewBookingScreen({super.key});

  @override
  ConsumerState<NewBookingScreen> createState() => _NewBookingScreenState();
}

class _NewBookingScreenState extends ConsumerState<NewBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Campi form
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _internalNotesCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  int _partySize = 2;
  String _source = 'phone';
  String? _selectedTableId;
  String? _selectedGuestId;
  bool _saving = false;

  // Guest esistente o nuovo
  bool _newGuest = true;
  List<GuestModel> _guests = [];
  List<AreaModel> _areas = [];
  List<TableModel> _tables = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final guests = await ref.read(guestRepositoryProvider).getGuests();
    final areas = await ref.read(tableRepositoryProvider).getAreas();
    if (areas.isNotEmpty) {
      final tables = await ref.read(tableRepositoryProvider).getTablesByArea(areas.first.id);
      setState(() { _guests = guests; _areas = areas; _tables = tables; });
    } else {
      setState(() { _guests = guests; _areas = areas; });
    }
  }

  Future<void> _loadTablesForArea(String areaId) async {
    final tables = await ref.read(tableRepositoryProvider).getTablesByArea(areaId);
    setState(() { _tables = tables; _selectedTableId = null; });
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _surnameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    _notesCtrl.dispose(); _internalNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // Crea o recupera guest
      String guestId;
      if (_newGuest) {
        final guest = await ref.read(guestRepositoryProvider).createGuest(
          name: '${_nameCtrl.text} ${_surnameCtrl.text}'.trim(),
          phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
          email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
        );
        guestId = guest.id;
      } else {
        guestId = _selectedGuestId!;
      }

      // Crea prenotazione
      final timeStr = '${_selectedTime.hour.toString().padLeft(2,'0')}:${_selectedTime.minute.toString().padLeft(2,'0')}:00';
      final endTime = TimeOfDay(hour: (_selectedTime.hour + 2) % 24, minute: _selectedTime.minute);
      final endTimeStr = '${endTime.hour.toString().padLeft(2,'0')}:${endTime.minute.toString().padLeft(2,'0')}:00';

      await ref.read(bookingRepositoryProvider).createBooking(BookingModel(
        id: '',
        restaurantId: '2b126a92-24d5-4e83-b38c-dfc82035a0cf',
        guestId: guestId,
        tableId: _selectedTableId,
        date: _selectedDate,
        timeStart: timeStr,
        timeEnd: endTimeStr,
        partySize: _partySize,
        status: 'confirmed',
        source: _source,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        internalNotes: _internalNotesCtrl.text.isEmpty ? null : _internalNotesCtrl.text,
        createdAt: DateTime.now(),
      ));

      ref.invalidate(bookingsByDateProvider);
      ref.invalidate(guestsProvider);
      // Imposta la data selezionata al giorno della prenotazione
      ref.read(selectedDateProvider.notifier).state = _selectedDate;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prenotazione creata!'), backgroundColor: AppColors.accent),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nuova prenotazione',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        actions: [
          _saving
              ? const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)))
              : TextButton(
                  onPressed: _submitForm,
                  child: const Text('Salva', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── CLIENTE ─────────────────────────────
              _SectionTitle(title: 'Cliente'),
              const SizedBox(height: 10),
              Row(children: [
                _TabButton(label: 'Nuovo cliente', selected: _newGuest, onTap: () => setState(() => _newGuest = true)),
                const SizedBox(width: 8),
                _TabButton(label: 'Cliente esistente', selected: !_newGuest, onTap: () => setState(() => _newGuest = false)),
              ]),
              const SizedBox(height: 12),

              if (_newGuest) ...[
                _buildField(_nameCtrl, 'Nome *', Icons.person_outline, required: true),
                const SizedBox(height: 10),
                _buildField(_surnameCtrl, 'Cognome *', Icons.person_outline, required: true),
                const SizedBox(height: 10),
                _buildField(_phoneCtrl, 'Telefono', Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 10),
                _buildField(_emailCtrl, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
              ] else ...[
                Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGuestId,
                      hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Seleziona cliente', style: TextStyle(color: AppColors.textMuted))),
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      items: _guests.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.name, style: const TextStyle(color: AppColors.textPrimary)),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedGuestId = v),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── DATA E ORA ───────────────────────────
              _SectionTitle(title: 'Data e ora'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _InfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Data',
                  value: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime(2027),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                )),
                const SizedBox(width: 10),
                Expanded(child: _InfoTile(
                  icon: Icons.access_time,
                  label: 'Orario',
                  value: '${_selectedTime.hour.toString().padLeft(2,'0')}:${_selectedTime.minute.toString().padLeft(2,'0')}',
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                    if (picked != null) setState(() => _selectedTime = picked);
                  },
                )),
              ]),

              const SizedBox(height: 20),

              // ── OSPITI ───────────────────────────────
              _SectionTitle(title: 'Numero ospiti'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                child: Row(children: [
                  const Icon(Icons.people_outline, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  const Text('Ospiti', style: TextStyle(color: AppColors.textSecondary)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.accent), onPressed: () => setState(() { if (_partySize > 1) _partySize--; })),
                  Text('$_partySize', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.accent), onPressed: () => setState(() => _partySize++)),
                ]),
              ),

              const SizedBox(height: 20),

              // ── TAVOLO ───────────────────────────────
              _SectionTitle(title: 'Tavolo (opzionale)'),
              const SizedBox(height: 10),
              if (_areas.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _areas.map((area) => GestureDetector(
                      onTap: () => _loadTablesForArea(area.id),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(area.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _selectedTableId = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTableId == null ? AppColors.accentLight : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _selectedTableId == null ? AppColors.accent : AppColors.divider),
                        ),
                        child: Text('Nessuno', style: TextStyle(color: _selectedTableId == null ? AppColors.accent : AppColors.textSecondary, fontSize: 13)),
                      ),
                    ),
                    ..._tables.map((table) => GestureDetector(
                      onTap: () => setState(() => _selectedTableId = table.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTableId == table.id ? AppColors.accentLight : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _selectedTableId == table.id ? AppColors.accent : AppColors.divider),
                        ),
                        child: Column(children: [
                          Text(table.name, style: TextStyle(color: _selectedTableId == table.id ? AppColors.accent : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${table.capacity}p', style: TextStyle(color: _selectedTableId == table.id ? AppColors.accent : AppColors.textMuted, fontSize: 11)),
                        ]),
                      ),
                    )),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // ── SORGENTE ─────────────────────────────
              _SectionTitle(title: 'Sorgente'),
              const SizedBox(height: 10),
              Row(children: [
                for (final s in [('phone','Telefono',Icons.phone),('web','Web',Icons.language),('walkin','Walk-in',Icons.directions_walk),('app','App',Icons.smartphone)])
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _source = s.$1),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _source == s.$1 ? AppColors.accentLight : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _source == s.$1 ? AppColors.accent : AppColors.divider),
                      ),
                      child: Column(children: [
                        Icon(s.$3, color: _source == s.$1 ? AppColors.accent : AppColors.textSecondary, size: 20),
                        const SizedBox(height: 4),
                        Text(s.$2, style: TextStyle(color: _source == s.$1 ? AppColors.accent : AppColors.textSecondary, fontSize: 11)),
                      ]),
                    ),
                  )),
              ]),

              const SizedBox(height: 20),

              // ── NOTE ─────────────────────────────────
              _SectionTitle(title: 'Note'),
              const SizedBox(height: 10),
              _buildField(_notesCtrl, 'Note cliente (allergie, preferenze...)', Icons.note_outlined, maxLines: 3),
              const SizedBox(height: 10),
              _buildField(_internalNotesCtrl, 'Note interne (solo staff)', Icons.lock_outline, maxLines: 2),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Crea prenotazione', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType? type, int maxLines = 1, bool required = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Campo obbligatorio' : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5));
}

class _TabButton extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _TabButton({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.accent : AppColors.divider),
      ),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String label, value; final VoidCallback onTap;
  const _InfoTile({required this.icon, required this.label, required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
      child: Row(children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
      ]),
    ),
  );
}
