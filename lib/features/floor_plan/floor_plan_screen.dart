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
    String best = '20:30';
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
          .select('id, name, capacity, position_x, position_y, shape')
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
        final endParts = (b['time_end'] as String).substring(0, 5).split(':');
        final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
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
    final hasPositions = _tables.any((t) => t['position_x'] != null && t['position_y'] != null);
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
          final x = (t['position_x'] as num?)?.toDouble() ?? 50;
          final y = (t['position_y'] as num?)?.toDouble() ?? 50;
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Tavolo ${table['name']}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${table['capacity']} posti',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ]),
            const SizedBox(height: 16),
            Text(
              status == TableStatus.free ? 'Libero alle $_selectedTime' : 'Occupato alle $_selectedTime',
              style: TextStyle(
                color: status == TableStatus.free ? const Color(0xFF2E7D52) : const Color(0xFFE65100),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            if (status == TableStatus.free)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/bookings/new');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nuova prenotazione'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D52)),
                ),
              ),
          ],
        ),
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
