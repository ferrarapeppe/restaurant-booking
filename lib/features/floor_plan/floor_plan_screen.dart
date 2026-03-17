import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:intl/intl.dart';

// Stato tavolo
enum TableStatus { free, booked, occupied, unavailable }

class FloorPlanScreen extends StatefulWidget {
  final DateTime date;
  const FloorPlanScreen({super.key, required this.date});

  @override
  State<FloorPlanScreen> createState() => _FloorPlanScreenState();
}

class _FloorPlanScreenState extends State<FloorPlanScreen> {
  static const String _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  final _supabase = Supabase.instance.client;

  late DateTime _selectedDate;
  String _selectedTime = '';
  List<String> _timeSlots = [];
  List<Map<String, dynamic>> _tables = [];
  Map<String, TableStatus> _tableStatuses = {};
  bool _loading = true;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date;
    _generateTimeSlots();
    _loadData();
  }

  void _generateTimeSlots() {
    final slots = <String>[];
    for (int h = 12; h <= 23; h++) {
      for (int m = 0; m < 60; m += 15) {
        slots.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      }
    }
    // Slot predefinito = 20:30 o il più vicino all'ora attuale
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    String best = '20:00';
    // Default fisso 20:00 per ristorante serale
    _timeSlots = slots;
    _selectedTime = '20:00';
    return;
    int bestDiff = 9999;
    for (final s in slots) {
      final parts = s.split(':');
      final sm = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      final diff = (sm - nowMinutes).abs();
      if (diff < bestDiff) { bestDiff = diff; best = s; }
    }
    _timeSlots = slots;
    _selectedTime = best;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Carica tavoli
      final tablesRes = await _supabase
          .from('tables')
          .select('id, name, capacity, pos_x, pos_y, shape')
          .eq('restaurant_id', _restaurantId)
          .order('name');

      // Carica prenotazioni del giorno
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final bookingsRes = await _supabase
          .from('bookings')
          .select('table_id, time_start, time_end, status')
          .eq('restaurant_id', _restaurantId)
          .eq('date', dateStr)
          .inFilter('status', ['confirmed', 'pending', 'seated']);

      // Calcola stati tavoli per lo slot selezionato
      final statuses = <String, TableStatus>{};
      final selParts = _selectedTime.split(':');
      final selMinutes = int.parse(selParts[0]) * 60 + int.parse(selParts[1]);

      for (final t in tablesRes) {
        statuses[t['id']] = TableStatus.free;
      }
      for (final b in bookingsRes) {
        if (b['table_id'] == null) continue;
        final startParts = (b['time_start'] as String).substring(0, 5).split(':');
        final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        // Se time_end è null assumiamo 2 ore di durata
        int endMin;
        if (b['time_end'] != null) {
          final endParts = (b['time_end'] as String).substring(0, 5).split(':');
          endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        } else {
          endMin = startMin + 120;
        }
        if (selMinutes >= startMin && selMinutes < endMin) {
          statuses[b['table_id']] = b['status'] == 'seated'
              ? TableStatus.occupied
              : TableStatus.booked;
        }
      }

      setState(() {
        _tables = List<Map<String, dynamic>>.from(tablesRes);
        _tableStatuses = statuses;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _onTimeSelected(String time) {
    setState(() => _selectedTime = time);
    _loadData();
  }

  void _changeDate(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
    _loadData();
  }

  Color _statusColor(TableStatus s) {
    switch (s) {
      case TableStatus.free: return const Color(0xFF2E7D52);
      case TableStatus.booked: return const Color(0xFFE65100);
      case TableStatus.occupied: return const Color(0xFFE65100);
      case TableStatus.unavailable: return const Color(0xFF424242);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEE d MMM', 'it_IT').format(_selectedDate);
    // Statistiche
    final total = _tables.length;
    final booked = _tableStatuses.values.where((s) => s != TableStatus.free && s != TableStatus.unavailable).length;
    final free = _tableStatuses.values.where((s) => s == TableStatus.free).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFFB8860B)),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
              onPressed: () => _changeDate(-1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2027),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark(),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _loadData();
                }
              },
              child: Text(
                _capitalize(dayLabel),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
              onPressed: () => _changeDate(1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today_outlined, color: AppColors.textPrimary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search, color: AppColors.textPrimary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Column(
              children: [
                // Barra statistiche
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Text('Totale $total', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                      Text('Occupati $booked', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const Text(' • ', style: TextStyle(color: AppColors.textSecondary)),
                      Text('Liberi $free', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                // Timeline oraria
                _TimelineBar(
                  slots: _timeSlots,
                  selected: _selectedTime,
                  onSelected: _onTimeSelected,
                ),
                // Canvas tavoli
                Expanded(
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 3.0,
                        child: _tables.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.table_restaurant, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                                    const SizedBox(height: 12),
                                    const Text('Nessun tavolo configurato', style: TextStyle(color: AppColors.textSecondary)),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text('Aggiungi tavoli in Impostazioni', style: TextStyle(color: AppColors.accent)),
                                    ),
                                  ],
                                ),
                              )
                            : _buildFloorGrid(),
                      ),
                      // Zoom controls
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Column(
                          children: [
                            _ZoomButton(icon: Icons.add, onTap: () {}),
                            const SizedBox(height: 4),
                            _ZoomButton(icon: Icons.remove, onTap: () {}),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/bookings/new'),
        backgroundColor: const Color(0xFF2E7D52),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFloorGrid() {
    // Se i tavoli hanno position_x/y usiamo posizionamento assoluto, altrimenti griglia
    final hasPositions = _tables.any((t) => t['pos_x'] != null && t['pos_y'] != null);
    if (hasPositions) {
      return _buildPositionedLayout();
    }
    return _buildGridLayout();
  }

  Widget _buildGridLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _tables.map((t) {
          final status = _tableStatuses[t['id']] ?? TableStatus.free;
          return _TableWidget(
            table: t,
            status: status,
            color: _statusColor(status),
            onTap: () => _onTableTap(t, status),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPositionedLayout() {
    const canvasW = 800.0;
    const canvasH = 600.0;
    return SizedBox(
      width: canvasW,
      height: canvasH,
      child: Stack(
        children: _tables.map((t) {
          final status = _tableStatuses[t['id']] ?? TableStatus.free;
          final x = (t['pos_x'] as num?)?.toDouble() ?? 50;
          final y = (t['pos_y'] as num?)?.toDouble() ?? 50;
          return Positioned(
            left: x,
            top: y,
            child: _TableWidget(
              table: t,
              status: status,
              color: _statusColor(status),
              onTap: () => _onTableTap(t, status),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _onTableTap(Map<String, dynamic> table, TableStatus status) {
    // Trova la prenotazione per questo tavolo allo slot selezionato
    Map<String, dynamic>? booking;
    // Cerchiamo nei dati già caricati — ricarichiamo le prenotazioni con dettagli ospite
    _loadBookingForTable(table, status);
  }

  Future<void> _loadBookingForTable(Map<String, dynamic> table, TableStatus status) async {
    Map<String, dynamic>? booking;
    if (status != TableStatus.free) {
      try {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        final selParts = _selectedTime.split(':');
        final selMin = int.parse(selParts[0]) * 60 + int.parse(selParts[1]);
        final res = await _supabase
            .from('bookings')
            .select('*, guests(first_name, surname, email, phone)')
            .eq('restaurant_id', _restaurantId)
            .eq('date', dateStr)
            .eq('table_id', table['id'])
            .inFilter('status', ['confirmed', 'pending', 'seated'])
            .limit(5);
        for (final b in res) {
          final startParts = (b['time_start'] as String).substring(0, 5).split(':');
          final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
          int endMin = startMin + 120;
          if (b['time_end'] != null) {
            final endParts = (b['time_end'] as String).substring(0, 5).split(':');
            endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
          }
          if (selMin >= startMin && selMin < endMin) { booking = b; break; }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TableDetailSheet(
        table: table,
        status: status,
        booking: booking,
        selectedDate: _selectedDate,
        selectedTime: _selectedTime,
        statusColor: _statusColor(status),
        onNewBooking: () { Navigator.pop(context); context.push('/bookings/new'); },
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Timeline Bar ──────────────────────────────────────────────────────────────
class _TimelineBar extends StatefulWidget {
  final List<String> slots;
  final String selected;
  final ValueChanged<String> onSelected;
  const _TimelineBar({required this.slots, required this.selected, required this.onSelected});

  @override
  State<_TimelineBar> createState() => _TimelineBarState();
}

class _TimelineBarState extends State<_TimelineBar> {
  late ScrollController _sc;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _scrollToSelected() {
    final idx = widget.slots.indexOf(widget.selected);
    if (idx >= 0) {
      _sc.animateTo(
        idx * 60.0 - 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      color: AppColors.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () => _sc.animateTo(
              _sc.offset - 180,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _sc,
              scrollDirection: Axis.horizontal,
              itemCount: widget.slots.length,
              itemExtent: 60,
              itemBuilder: (_, i) {
                final slot = widget.slots[i];
                final isSelected = slot == widget.selected;
                return GestureDetector(
                  onTap: () => widget.onSelected(slot),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2E7D52) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slot,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Dot se ci sono prenotazioni (placeholder)
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white70 : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            onPressed: () => _sc.animateTo(
              _sc.offset + 180,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { _sc.dispose(); super.dispose(); }
}

// ── Tavolo Widget ─────────────────────────────────────────────────────────────
class _TableWidget extends StatelessWidget {
  final Map<String, dynamic> table;
  final TableStatus status;
  final Color color;
  final VoidCallback onTap;
  const _TableWidget({required this.table, required this.status, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = table['name']?.toString() ?? '?';
    final cap = table['capacity']?.toString() ?? '';
    final isRound = (table['shape'] ?? 'round') == 'round';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: color,
          shape: isRound ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isRound ? null : BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            if (cap.isNotEmpty)
              Text(cap, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Zoom Button ───────────────────────────────────────────────────────────────
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

// ── Table Detail Sheet ────────────────────────────────────────────────────────
class _TableDetailSheet extends StatefulWidget {
  final Map<String, dynamic> table;
  final TableStatus status;
  final Map<String, dynamic>? booking;
  final DateTime selectedDate;
  final String selectedTime;
  final Color statusColor;
  final VoidCallback onNewBooking;

  const _TableDetailSheet({
    required this.table,
    required this.status,
    required this.booking,
    required this.selectedDate,
    required this.selectedTime,
    required this.statusColor,
    required this.onNewBooking,
  });

  @override
  State<_TableDetailSheet> createState() => _TableDetailSheetState();
}

class _TableDetailSheetState extends State<_TableDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  // Controllers editabili
  late TextEditingController _nomeCtrl;
  late TextEditingController _cognomeCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _msgCtrl;

  late DateTime _editDate;
  late String _editTime;
  late int _editPartySize;
  late String _editStatus;
  late String _editSource;
  bool _saving = false;
  bool _notifyEmail = false;
  int _cenaSel = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _editDate = widget.selectedDate;
    _editPartySize = widget.booking?['party_size'] ?? 2;
    _editStatus = widget.booking?['status'] ?? 'confirmed';
    _editSource = widget.booking?['source'] ?? 'phone';

    final g = widget.booking?['guests'];
    _nomeCtrl = TextEditingController(text: (g?['first_name'] ?? '').toString());
    _cognomeCtrl = TextEditingController(text: (g?['surname'] ?? '').toString().toUpperCase());
    _telefonoCtrl = TextEditingController(text: (g?['phone'] ?? '').toString());
    _emailCtrl = TextEditingController(text: (g?['email'] ?? '').toString());
    _noteCtrl = TextEditingController();
    _msgCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeCtrl.dispose(); _cognomeCtrl.dispose();
    _telefonoCtrl.dispose(); _emailCtrl.dispose();
    _noteCtrl.dispose(); _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.booking == null) return;
    setState(() => _saving = true);
    try {
      final guestId = widget.booking!['guest_id'];
      // Aggiorna guest
      if (guestId != null) {
        await _supabase.from('guests').update({
          'first_name': _nomeCtrl.text.trim(),
          'surname': _cognomeCtrl.text.trim(),
          'phone': _telefonoCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
        }).eq('id', guestId);
      }
      // Aggiorna booking
      final dateStr = DateFormat('yyyy-MM-dd').format(_editDate);
      await _supabase.from('bookings').update({
        'date': dateStr,
        'time_start': _editTime + ':00',
        'party_size': _editPartySize,
        'status': _editStatus,
        'source': _editSource,
      }).eq('id', widget.booking!['id']);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prenotazione salvata'), backgroundColor: Color(0xFF2E7D52)),
        );
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

  void _changeTime(int deltaMinutes) {
    final parts = _editTime.split(':');
    int minutes = int.parse(parts[0]) * 60 + int.parse(parts[1]) + deltaMinutes;
    minutes = minutes.clamp(0, 23 * 60 + 45);
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    setState(() => _editTime = '$h:$m');
  }

  String get _statusLabel {
    switch (_editStatus) {
      case 'confirmed': return '👍 Accettato';
      case 'seated': return '🍽️ Al tavolo';
      case 'pending': return '⏳ In attesa';
      case 'cancelled': return '❌ Cancellato';
      case 'noshow': return '🚫 No show';
      default: return _editStatus;
    }
  }

  String get _sourceLabel {
    switch (_editSource) {
      case 'phone': return '📞 Telefono';
      case 'web': return '🌐 Web';
      case 'walkin': return '🚶 Walk-in';
      case 'google': return '🔍 Google';
      default: return _editSource;
    }
  }

  Color get _statusColor {
    switch (_editStatus) {
      case 'confirmed': return const Color(0xFF2E7D52);
      case 'seated': return const Color(0xFF1565C0);
      case 'pending': return const Color(0xFFE65100);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE d MMM yyyy', 'it_IT').format(_editDate);
    final isOccupied = widget.status != TableStatus.free;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF2E7D52),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1),
            tabs: const [Tab(text: 'DETTAGLI'), Tab(text: 'MESSAGGI, NOTE')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── TAB DETTAGLI ──
                ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    // Data
                    _DetailRow(
                      label: 'Data',
                      child: Row(children: [
                        Expanded(child: Text(_capitalize(dateLabel),
                            style: const TextStyle(color: Colors.white, fontSize: 16))),
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white54, size: 20),
                          onPressed: () => setState(() => _editDate = _editDate.subtract(const Duration(days: 1))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                          onPressed: () => setState(() => _editDate = _editDate.add(const Duration(days: 1))),
                        ),
                      ]),
                    ),
                    const Divider(color: Colors.white12),
                    // Ora
                    _DetailRow(
                      label: 'Ora',
                      child: Row(children: [
                        Expanded(child: Text(_editTime,
                            style: const TextStyle(color: Colors.white, fontSize: 16))),
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 20),
                            onPressed: () => _changeTime(-15)),
                        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54, size: 20),
                            onPressed: () => _changeTime(15)),
                      ]),
                    ),
                    const Divider(color: Colors.white12),
                    // Persone
                    _DetailRow(
                      label: 'Persone',
                      child: Row(children: [
                        Expanded(child: Text('$_editPartySize',
                            style: const TextStyle(color: Colors.white, fontSize: 16))),
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 20),
                            onPressed: () => setState(() => _editPartySize = (_editPartySize - 1).clamp(1, 20))),
                        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54, size: 20),
                            onPressed: () => setState(() => _editPartySize = (_editPartySize + 1).clamp(1, 20))),
                      ]),
                    ),
                    const Divider(color: Colors.white12),
                    // Tavolo chip
                    _DetailRow(
                      label: 'Tavolo',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: widget.statusColor),
                        ),
                        child: Text(
                          '${widget.table['name']}  ${widget.table['capacity']}-${widget.table['min_capacity'] ?? widget.table['capacity']}',
                          style: TextStyle(color: widget.statusColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isOccupied) ...[
                      // Nome editabile
                      _EditField(label: 'Nome (o trova per nome, telefono, email)', controller: _nomeCtrl),
                      const SizedBox(height: 8),
                      // Telefono
                      _EditField(label: 'Telefono', controller: _telefonoCtrl, prefix: 'Italy (+39)', keyboardType: TextInputType.phone),
                      const SizedBox(height: 8),
                      // Email
                      _EditField(label: 'E-mail', controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 8),
                      // Cognome
                      _EditField(label: 'COGNOME', controller: _cognomeCtrl),
                      const SizedBox(height: 16),
                      // CENA
                      _CenaSelector(),
                      const SizedBox(height: 8),
                      // Regole
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Text('REGOLE DI PRENOTAZIONE',
                            style: TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 0.5)),
                      ),
                      const SizedBox(height: 16),
                      // Toggle notifiche
                      const Text('Invia notifiche all\'ospite',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Switch(
                          value: _notifyEmail,
                          onChanged: (v) => setState(() => _notifyEmail = v),
                          activeColor: const Color(0xFF2E7D52),
                        ),
                        const SizedBox(width: 8),
                        const Text('E-mail', style: TextStyle(color: Colors.white70, fontSize: 15)),
                      ]),
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white12),
                      // Orari apertura
                      _DetailRow(
                        label: 'Orari di apertura',
                        child: Row(children: [
                          const Expanded(child: Text('18:30 - 01:00',
                              style: TextStyle(color: Colors.white70, fontSize: 15))),
                          const Icon(Icons.arrow_drop_down, color: Colors.white38),
                        ]),
                      ),
                      const Divider(color: Colors.white12),
                      // Durata
                      _DetailRow(
                        label: 'Durata',
                        child: Row(children: [
                          const Expanded(child: Text('2:00',
                              style: TextStyle(color: Colors.white70, fontSize: 15))),
                          const Icon(Icons.arrow_drop_down, color: Colors.white38),
                          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 20), onPressed: () {}),
                          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white54, size: 20), onPressed: () {}),
                        ]),
                      ),
                      const Divider(color: Colors.white12),
                      // Stato dropdown
                      _DetailRow(
                        label: 'Stato',
                        child: DropdownButton<String>(
                          value: _editStatus,
                          dropdownColor: const Color(0xFF2A2A3E),
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'confirmed', child: Text('👍 Accettato', style: TextStyle(color: Colors.white70))),
                            DropdownMenuItem(value: 'seated', child: Text('🍽️ Al tavolo', style: TextStyle(color: Colors.white70))),
                            DropdownMenuItem(value: 'pending', child: Text('⏳ In attesa', style: TextStyle(color: Colors.white70))),
                            DropdownMenuItem(value: 'cancelled', child: Text('❌ Cancellato', style: TextStyle(color: Colors.white70))),
                            DropdownMenuItem(value: 'noshow', child: Text('🚫 No show', style: TextStyle(color: Colors.white70))),
                          ],
                          onChanged: (v) => setState(() => _editStatus = v!),
                        ),
                      ),
                      const Divider(color: Colors.white12),
                      // Sorgente dropdown
                      _DetailRow(
                        label: 'Sorgente',
                        child: DropdownButton<String>(
                          value: _editSource,
                          dropdownColor: const Color(0xFF2A2A3E),
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'phone', child: Text('📞 Telefono', style: TextStyle(color: Colors.white70))),
                            DropdownMenuItem(value: 'web', child: Text('🌐 Web', style: TextStyle(color: Colors.white70))),
                            DropdownMenuItem(value: 'walkin', child: Text('🚶 Walk-in', style: TextStyle(color: Colors.white70))),
                            DropdownMenuItem(value: 'google', child: Text('🔍 Google', style: TextStyle(color: Colors.white70))),
                          ],
                          onChanged: (v) => setState(() => _editSource = v!),
                        ),
                      ),
                      const Divider(color: Colors.white12),
                      // Link pagamento
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Stato della prenotazione e link di pagamento',
                                style: TextStyle(color: Colors.white38, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.link, color: Colors.white38, size: 18),
                              const SizedBox(width: 8),
                              Text('Mostra', style: TextStyle(color: Colors.blue.shade300, fontSize: 14)),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      const SizedBox(height: 16),
                      const Text('Tavolo libero', style: TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ],
                ),
                // ── TAB MESSAGGI, NOTE ──
                Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (isOccupied) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF2E7D52),
                                  child: Text(
                                    _nomeCtrl.text.isNotEmpty ? _nomeCtrl.text[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_nomeCtrl.text} ${_cognomeCtrl.text}  •  poco fa'.trim(),
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                              child: const Text('Prenotazione creata', style: TextStyle(color: Colors.white70)),
                            ),
                          ] else
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 40),
                                child: Text('Nessun messaggio', style: TextStyle(color: Colors.white38)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
                      child: DefaultTabController(
                        length: 2,
                        child: Column(children: [
                          const TabBar(
                            indicatorColor: Color(0xFF2E7D52),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.white38,
                            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            tabs: [Tab(text: 'MESSAGGIO'), Tab(text: 'NOTA')],
                          ),
                          SizedBox(
                            height: 56,
                            child: TabBarView(children: [
                              _MessageInput(controller: _msgCtrl, hint: 'Messaggio all\'ospite...',
                                  color: const Color(0xFF1A1A2E)),
                              _MessageInput(controller: _noteCtrl, hint: 'Nota interna privata...',
                                  color: const Color(0xFF1565C0), isNote: true),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Bottom action bar
          Container(
            color: const Color(0xFF1E1E2E),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isOccupied) ...[
                  _ActionButton(icon: Icons.more_horiz, onTap: () {}),
                  const SizedBox(width: 12),
                  _ActionButton(icon: Icons.close, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  _saving
                      ? const CircularProgressIndicator(color: Color(0xFF2E7D52))
                      : _ActionButton(icon: Icons.check, color: const Color(0xFF2E7D52), onTap: _save),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onNewBooking,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuova prenotazione'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D52),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String value;
  final String? prefix;
  const _InputField({required this.label, required this.value, this.prefix});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 4),
          if (prefix != null)
            Row(children: [
              Text(prefix!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
              const Icon(Icons.arrow_drop_down, color: Colors.white38, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ])
          else
            Text(
              value.isNotEmpty ? value : '',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color color;
  final bool isNote;
  const _MessageInput({required this.controller, required this.hint, required this.color, this.isNote = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white38),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Icon(
            isNote ? Icons.add_comment_outlined : Icons.send,
            color: Colors.white38,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _ActionButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: color ?? Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ── Cena Selector ─────────────────────────────────────────────────────────────
class _CenaSelector extends StatefulWidget {
  const _CenaSelector();
  @override
  State<_CenaSelector> createState() => _CenaSelectorState();
}

class _CenaSelectorState extends State<_CenaSelector> {
  int _selected = 1;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CENA', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 8),
          _RadioOption(value: 0, groupValue: _selected, label: 'APERTIF/APERITIVO DALLE 18:30\nALLE 20:30', onChanged: (v) => setState(() => _selected = v)),
          _RadioOption(value: 1, groupValue: _selected, label: 'DINNER/CENA 1° TURNO 20:30  2° TURNO 22:30', onChanged: (v) => setState(() => _selected = v)),
        ],
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  final int value, groupValue;
  final String label;
  final ValueChanged<int> onChanged;
  const _RadioOption({required this.value, required this.groupValue, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<int>(
              value: value, groupValue: groupValue,
              onChanged: (v) => onChanged(v!),
              activeColor: const Color(0xFFC9B06E),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit Field ────────────────────────────────────────────────────────────────
class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix;
  final TextInputType? keyboardType;
  const _EditField({required this.label, required this.controller, this.prefix, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          Row(children: [
            if (prefix != null) ...[
              Text(prefix!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
              const Icon(Icons.arrow_drop_down, color: Colors.white38, size: 18),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
