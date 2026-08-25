import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/features/bookings/bookings_screen.dart';
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
  List<Map<String, dynamic>> _pendingBookings = [];
  List<Map<String, dynamic>> _areas = [];
  String? _selectedAreaId;
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
          .select('id, name, capacity, pos_x, pos_y, shape, area_id')
          .eq('restaurant_id', _restaurantId)
          .order('name');

      // Carica aree
      final areasRes = await _supabase
          .from('areas')
          .select('id, name')
          .eq('restaurant_id', _restaurantId)
          .order('name');

      // Carica prenotazioni del giorno
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final bookingsRes = await _supabase
          .from('bookings')
          .select('table_id, time_start, time_end, status')
          .eq('restaurant_id', _restaurantId)
          .eq('date', dateStr)
          .inFilter('status', ['approved', 'pending', 'seated']);

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

      // Carica tutte le prenotazioni pending (con e senza tavolo)
      final pendingRes = await _supabase
          .from('bookings')
          .select('*, guests(first_name, surname, name, phone, email), tables(name, capacity)')
          .eq('restaurant_id', _restaurantId)
          .eq('date', dateStr)
          .eq('status', 'pending');

      final areas = List<Map<String, dynamic>>.from(areasRes);
      setState(() {
        _tables = List<Map<String, dynamic>>.from(tablesRes);
        _tableStatuses = statuses;
        _pendingBookings = List<Map<String, dynamic>>.from(pendingRes);
        _areas = areas;
        _selectedAreaId ??= areas.isNotEmpty ? areas.first['id'] as String : null;
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
      case TableStatus.free: return AppColors.accent;
      case TableStatus.booked: return AppColors.accent;
      case TableStatus.occupied: return AppColors.accent;
      case TableStatus.unavailable: return AppColors.textPrimary;
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
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
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
                // Tab aree
                if (_areas.isNotEmpty)
                  Container(
                    height: 44,
                    color: AppColors.surface,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      itemCount: _areas.length,
                      itemBuilder: (_, i) {
                        final area = _areas[i];
                        final isSelected = area['id'] == _selectedAreaId;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedAreaId = area['id'] as String),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accent : AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? AppColors.accent : AppColors.divider),
                            ),
                            child: Text(
                              area['name'] as String,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                // Tavoli mai posizionati: finche' non lo sono, la piantina non
                // rispecchia la sala e serve a poco.
                if (_tavoliSenzaPosizione > 0)
                  Container(
                    color: AppColors.accentLight,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.grid_view_outlined, color: AppColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _tavoliSenzaPosizione == 1
                              ? 'Un tavolo non è ancora al suo posto'
                              : '$_tavoliSenzaPosizione tavoli non sono ancora al loro posto',
                          style: const TextStyle(
                              color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: _fissaDisposizione,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Disponi in griglia',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  ),
                // Barra prenotazioni pending
                if (_pendingBookings.isNotEmpty)
                  Container(
                    color: AppColors.gold.withOpacity(0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      const Icon(Icons.pending_actions, color: AppColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_pendingBookings.length} prenotazion${_pendingBookings.length == 1 ? "e" : "i"} in attesa',
                          style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showPendingBookings(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Vedi', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
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
        backgroundColor: AppColors.accent,
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

  /// Dove mettere un tavolo che non e' mai stato spostato.
  ///
  /// Prima finivano tutti a (50,50), uno esattamente sopra l'altro: la
  /// planimetria sembrava avere un tavolo solo, mentre erano tutti impilati
  /// nello stesso punto. Ora si dispongono in griglia, visibili e trascinabili.
  static Offset _posizioneDiRipiego(int indice) {
    const colonne = 6;
    const passoX = 115.0, passoY = 105.0, margine = 30.0;
    return Offset(
      margine + (indice % colonne) * passoX,
      margine + (indice ~/ colonne) * passoY,
    );
  }

  /// Un tavolo mai posizionato.
  ///
  /// In archivio le coordinate non sono nulle: sono tutte a zero. Uno zero-zero
  /// non vuol dire "il tavolo sta nell'angolo in alto a sinistra", vuol dire
  /// che nessuno l'ha mai spostato — ed e' il motivo per cui finivano tutti
  /// nello stesso punto.
  static bool _senzaPosizione(Map<String, dynamic> t) {
    final x = (t['pos_x'] as num?)?.toDouble();
    final y = (t['pos_y'] as num?)?.toDouble();
    return x == null || y == null || (x == 0 && y == 0);
  }

  /// Quanti tavoli non hanno ancora una posizione vera.
  int get _tavoliSenzaPosizione => _tables.where(_senzaPosizione).length;

  /// Posto di ciascun tavolo dentro la propria area: la piantina si guarda
  /// un'area per volta, quindi la griglia va contata li' dentro. Serve identico
  /// al disegno e al salvataggio, altrimenti "Disponi in griglia" sposterebbe
  /// i tavoli rispetto a come li vedevi un attimo prima.
  Map<String, int> _indiciNellArea() {
    final conteggio = <String, int>{};
    final indici = <String, int>{};
    for (final t in _tables) {
      final area = (t['area_id'] ?? '').toString();
      final i = conteggio[area] ?? 0;
      indici[t['id'].toString()] = i;
      conteggio[area] = i + 1;
    }
    return indici;
  }

  /// Fissa nel database la disposizione a griglia, cosi' smette di essere un
  /// ripiego calcolato ogni volta e diventa un punto di partenza modificabile.
  Future<void> _fissaDisposizione() async {
    final indici = _indiciNellArea();
    final daSistemare = <Map<String, dynamic>>[];
    for (final t in _tables) {
      if (_senzaPosizione(t)) {
        final p = _posizioneDiRipiego(indici[t['id'].toString()] ?? 0);
        daSistemare.add({'id': t['id'], 'x': p.dx, 'y': p.dy});
      }
    }
    if (daSistemare.isEmpty) return;
    var riusciti = 0;
    for (final d in daSistemare) {
      try {
        final righe = await _supabase
            .from('tables')
            .update({'pos_x': d['x'], 'pos_y': d['y']})
            .eq('id', d['id'] as String)
            .select();
        if (righe.isNotEmpty) riusciti++;
      } catch (e) {
        debugPrint('posizione non salvata: $e');
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor:
          riusciti == daSistemare.length ? AppColors.badgeGreen : AppColors.accent,
      content: Text(riusciti == daSistemare.length
          ? '$riusciti tavoli disposti in griglia. Ora trascinali dove stanno davvero.'
          : 'Salvati $riusciti tavoli su ${daSistemare.length}: il database ha rifiutato gli altri.'),
    ));
    _loadData();
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
    const canvasH = 700.0;
    final filteredTables = _selectedAreaId != null
        ? _tables.where((t) => t['area_id'] == _selectedAreaId).toList()
        : _tables;
    final indici = _indiciNellArea();
    return SizedBox(
      width: canvasW,
      height: canvasH,
      child: Stack(
        children: filteredTables.map((t) {
          final status = _tableStatuses[t['id']] ?? TableStatus.free;
          final ripiego = _posizioneDiRipiego(indici[t['id'].toString()] ?? 0);
          final senza = _senzaPosizione(t);
          final x = senza ? ripiego.dx : (t['pos_x'] as num).toDouble();
          final y = senza ? ripiego.dy : (t['pos_y'] as num).toDouble();
          return _DraggableTable(
            key: ValueKey(t['id']),
            table: t,
            x: x,
            y: y,
            status: status,
            color: _statusColor(status),
            onTap: () => _onTableTap(t, status),
            onDragEnd: (newX, newY) async {
              setState(() {
                t['pos_x'] = newX;
                t['pos_y'] = newY;
              });
              try {
                await _supabase.from('tables').update({
                  'pos_x': newX,
                  'pos_y': newY,
                }).eq('id', t['id'] as String);
              } catch (e) {
                debugPrint('Drag save error: $e');
              }
            },
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
            .inFilter('status', ['approved', 'pending', 'seated'])
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
      backgroundColor: Colors.white,
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
                      color: isSelected ? AppColors.accent : Colors.transparent,
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
                            color: isSelected ? AppColors.textSecondary : Colors.transparent,
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

// ── Draggable Table ───────────────────────────────────────────────────────────
class _DraggableTable extends StatefulWidget {
  final Map<String, dynamic> table;
  final double x, y;
  final TableStatus status;
  final Color color;
  final VoidCallback onTap;
  final void Function(double x, double y) onDragEnd;

  const _DraggableTable({
    super.key,
    required this.table,
    required this.x,
    required this.y,
    required this.status,
    required this.color,
    required this.onTap,
    required this.onDragEnd,
  });

  @override
  State<_DraggableTable> createState() => _DraggableTableState();
}

class _DraggableTableState extends State<_DraggableTable> {
  late double _x, _y;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _x = widget.x;
    _y = widget.y;
  }

  @override
  void didUpdateWidget(_DraggableTable old) {
    super.didUpdateWidget(old);
    if (!_dragging) {
      _x = widget.x;
      _y = widget.y;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onTap: _dragging ? null : widget.onTap,
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (d) => setState(() {
          _x = (_x + d.delta.dx).clamp(0, 740);
          _y = (_y + d.delta.dy).clamp(0, 640);
        }),
        onPanEnd: (_) {
          setState(() => _dragging = false);
          widget.onDragEnd(_x, _y);
        },
        child: Opacity(
          opacity: _dragging ? 0.7 : 1.0,
          child: _TableWidget(
            table: widget.table,
            status: widget.status,
            color: _dragging ? widget.color.withOpacity(0.8) : widget.color,
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}

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
  int _editDurationMinutes = 120;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _editDate = widget.selectedDate;
    _editTime = widget.booking != null && widget.booking!['time_start'] != null ? widget.booking!['time_start'].toString().substring(0, 5) : widget.selectedTime;
    _editPartySize = widget.booking?['party_size'] ?? 2;
    _editStatus = widget.booking?['status'] ?? 'approved';
    _editSource = widget.booking?['source'] ?? 'phone';

    final g = widget.booking?['guests'];
    _nomeCtrl = TextEditingController(text: g != null ? (g['first_name'] ?? '').toString() : '');
    _cognomeCtrl = TextEditingController(text: g != null ? (g['surname'] ?? '').toString().toUpperCase() : '');
    _telefonoCtrl = TextEditingController(text: g != null ? (g['phone'] ?? '').toString() : '');
    _emailCtrl = TextEditingController(text: g != null ? (g['email'] ?? '').toString() : '');
    _noteCtrl = TextEditingController(text: widget.booking?['internal_notes']?.toString() ?? '');
    _msgCtrl = TextEditingController(text: widget.booking?['notes']?.toString() ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeCtrl.dispose(); _cognomeCtrl.dispose();
    _telefonoCtrl.dispose(); _emailCtrl.dispose();
    _noteCtrl.dispose(); _msgCtrl.dispose();
    super.dispose();
  }

  String _calcTimeEnd() {
    final parts = _editTime.split(':');
    final startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final endMin = startMin + _editDurationMinutes;
    final h = (endMin ~/ 60).toString().padLeft(2, '0');
    final m = (endMin % 60).toString().padLeft(2, '0');
    return h + ':' + m + ':00';
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
        'notify_email': _notifyEmail,
        'notes': _msgCtrl.text.trim(),
        'internal_notes': _noteCtrl.text.trim(),
        'time_end': _calcTimeEnd(),
      }).eq('id', widget.booking!['id']);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prenotazione salvata'), backgroundColor: AppColors.accent),
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

  Future<void> _saveNew() async {
    if (_nomeCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final supabase = Supabase.instance.client;
      const restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
      // Crea o trova guest
      final guestRes = await supabase.from('guests').insert({
        'restaurant_id': restaurantId,
        'first_name': _nomeCtrl.text.trim(),
        'surname': _cognomeCtrl.text.trim(),
        'phone': _telefonoCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      }).select().single();
      final guestId = guestRes['id'] as String;
      // Crea prenotazione
      final dateStr = DateFormat('yyyy-MM-dd').format(_editDate);
      final timeEnd = _calcTimeEnd();
      await supabase.from('bookings').insert({
        'restaurant_id': restaurantId,
        'guest_id': guestId,
        'table_id': widget.table['id'],
        'date': dateStr,
        'time_start': '$_editTime:00',
        'time_end': timeEnd,
        'party_size': _editPartySize,
        'status': _editStatus,
        'source': _editSource,
        'notes': _msgCtrl.text.trim(),
        'internal_notes': _noteCtrl.text.trim(),
        'notify_email': _notifyEmail,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prenotazione creata'), backgroundColor: AppColors.accent),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
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
      case 'approved': return '👍 Accettato';
      case 'seated': return '🍽️ Al tavolo';
      case 'pending': return '⏳ In attesa';
      case 'canceled': return '❌ Cancellato';
      case 'no_show': return '🚫 No show';
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
      case 'approved': return AppColors.statoConfermato;
      case 'seated': return AppColors.textSecondary;
      case 'pending': return AppColors.statoAttesa;
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
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
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
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 20),
                          onPressed: () => setState(() => _editDate = _editDate.subtract(const Duration(days: 1))),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                          onPressed: () => setState(() => _editDate = _editDate.add(const Duration(days: 1))),
                        ),
                      ]),
                    ),
                    const Divider(color: AppColors.divider),
                    // Ora
                    _DetailRow(
                      label: 'Ora',
                      child: Row(children: [
                        Expanded(child: Text(_editTime,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 20),
                            onPressed: () => _changeTime(-15)),
                        IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 20),
                            onPressed: () => _changeTime(15)),
                      ]),
                    ),
                    const Divider(color: AppColors.divider),
                    // Persone
                    _DetailRow(
                      label: 'Persone',
                      child: Row(children: [
                        Expanded(child: Text('$_editPartySize',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                        IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 20),
                            onPressed: () => setState(() => _editPartySize = (_editPartySize - 1).clamp(1, 20))),
                        IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 20),
                            onPressed: () => setState(() => _editPartySize = (_editPartySize + 1).clamp(1, 20))),
                      ]),
                    ),
                    const Divider(color: AppColors.divider),
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
                    ...[
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
                          color: AppColors.cardLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Text('REGOLE DI PRENOTAZIONE',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13, letterSpacing: 0.5)),
                      ),
                      const SizedBox(height: 16),
                      // Toggle notifiche
                      const Text('Invia notifiche all\'ospite',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Switch(
                          value: _notifyEmail,
                          onChanged: (v) => setState(() => _notifyEmail = v),
                          activeColor: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        const Text('E-mail', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                      ]),
                      const SizedBox(height: 8),
                      const Divider(color: AppColors.divider),
                      // Orari apertura
                      _DetailRow(
                        label: 'Orari di apertura',
                        child: Row(children: [
                          const Expanded(child: Text('18:30 - 01:00',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 15))),
                          const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                        ]),
                      ),
                      const Divider(color: AppColors.divider),
                      // Durata
                      _DetailRow(
                        label: 'Durata',
                        child: Row(children: [
                          Expanded(child: Builder(builder: (context) {
                            final h = _editDurationMinutes ~/ 60;
                            final m = (_editDurationMinutes % 60).toString().padLeft(2, '0');
                            return Text('$h:$m', style: const TextStyle(color: AppColors.textSecondary, fontSize: 15));
                          })),
                          const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 20),
                            onPressed: () => setState(() => _editDurationMinutes = (_editDurationMinutes - 15).clamp(15, 480)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 20),
                            onPressed: () => setState(() => _editDurationMinutes = (_editDurationMinutes + 15).clamp(15, 480)),
                          ),
                        ]),
                      ),
                      const Divider(color: AppColors.divider),
                      // Stato dropdown
                      _DetailRow(
                        label: 'Stato',
                        child: DropdownButton<String>(
                          value: _editStatus,
                          dropdownColor: AppColors.surface,
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'approved', child: Text('👍 Accettato', style: TextStyle(color: AppColors.textSecondary))),
                            DropdownMenuItem(value: 'seated', child: Text('🍽️ Al tavolo', style: TextStyle(color: AppColors.textSecondary))),
                            DropdownMenuItem(value: 'pending', child: Text('⏳ In attesa', style: TextStyle(color: AppColors.textSecondary))),
                            DropdownMenuItem(value: 'canceled', child: Text('❌ Cancellato', style: TextStyle(color: AppColors.textSecondary))),
                            DropdownMenuItem(value: 'no_show', child: Text('🚫 No show', style: TextStyle(color: AppColors.textSecondary))),
                          ],
                          onChanged: (v) => setState(() => _editStatus = v!),
                        ),
                      ),
                      const Divider(color: AppColors.divider),
                      // Sorgente dropdown
                      _DetailRow(
                        label: 'Sorgente',
                        child: DropdownButton<String>(
                          value: _editSource,
                          dropdownColor: AppColors.surface,
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'phone', child: Text('📞 Telefono', style: TextStyle(color: AppColors.textSecondary))),
                            DropdownMenuItem(value: 'web', child: Text('🌐 Web', style: TextStyle(color: AppColors.textSecondary))),
                            DropdownMenuItem(value: 'walkin', child: Text('🚶 Walk-in', style: TextStyle(color: AppColors.textSecondary))),
                            DropdownMenuItem(value: 'google', child: Text('🔍 Google', style: TextStyle(color: AppColors.textSecondary))),
                          ],
                          onChanged: (v) => setState(() => _editSource = v!),
                        ),
                      ),
                      const Divider(color: AppColors.divider),
                      // Link pagamento
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Stato della prenotazione e link di pagamento',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.link, color: AppColors.textMuted, size: 18),
                              const SizedBox(width: 8),
                              Text('Mostra', style: TextStyle(color: Colors.blue.shade300, fontSize: 14)),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],




                  ],
                ),
                // ── TAB MESSAGGI ──
                // Prima: il campo "MESSAGGIO" scriveva in `notes`, sovrascrivendo
                // la nota lasciata dal cliente in fase di prenotazione, e il campo
                // "NOTA" scriveva in `internal_notes`, che pero' contiene il JSON
                // con turno e area: ci avrebbe distrutto dentro quei dati.
                widget.booking == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nessuna prenotazione selezionata.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    : ConversazioneCliente(bookingId: widget.booking!['id'] as String),
              ],
            ),
          ),
          // Bottom action bar
          Container(
            color: Colors.white,
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
                      ? const CircularProgressIndicator(color: AppColors.accent)
                      : _ActionButton(icon: Icons.check, color: AppColors.accent, onTap: _save),
                ] else ...[
                  _ActionButton(icon: Icons.more_horiz, onTap: () {}),
                  const SizedBox(width: 12),
                  _ActionButton(icon: Icons.close, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  _saving
                      ? const CircularProgressIndicator(color: AppColors.accent)
                      : _ActionButton(icon: Icons.check, color: AppColors.accent, onTap: _saveNew),
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          if (prefix != null)
            Row(children: [
              Text(prefix!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const Icon(Icons.arrow_drop_down, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                ),
              ),
            ])
          else
            Text(
              value.isNotEmpty ? value : '',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final Color color;
  final bool isNote;
  final Function()? onSend;
  const _MessageInput({required this.controller, required this.hint, required this.color, this.isNote = false, this.onSend});

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => widget.onSend?.call(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.onSend?.call();
            },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isNote ? Icons.add_comment_outlined : Icons.send,
                color: Colors.white,
                size: 18,
              ),
            ),
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
          color: color ?? AppColors.divider,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 22),
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
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CENA', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 1)),
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
              activeColor: AppColors.gold,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Row(children: [
            if (prefix != null) ...[
              Text(prefix!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const Icon(Icons.arrow_drop_down, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
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

// ── Pending Bookings Extension ────────────────────────────────────────────────
extension FloorPlanPending on _FloorPlanScreenState {
  void _showPendingBookings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Prenotazioni senza tavolo',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(color: AppColors.divider),
          Expanded(
            child: ListView.builder(
              controller: sc,
              padding: const EdgeInsets.all(16),
              itemCount: _pendingBookings.length,
              itemBuilder: (_, i) {
                final b = _pendingBookings[i];
                final g = b['guests'];
                final guestName = g != null
                    ? '${g['first_name'] ?? ''} ${g['surname'] ?? ''}'.trim()
                    : 'Ospite';
                final time = b['time_start']?.toString().substring(0, 5) ?? '';
                final persons = b['party_size'] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withOpacity(0.5)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(guestName.isEmpty ? 'Ospite' : guestName,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(width: 12),
                      const Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('$persons persone', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.table_restaurant_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        b['tables']?['name'] != null
                            ? 'Tavolo ${b['tables']['name']}  (${b['tables']['capacity']} posti)'
                            : 'Nessun tavolo assegnato',
                        style: TextStyle(
                          color: b['tables'] != null ? AppColors.accent : AppColors.gold,
                          fontSize: 13, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () { Navigator.pop(context); _acceptBooking(b); },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Accetta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () { Navigator.pop(context); _rejectBooking(b); },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Rifiuta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _acceptBooking(Map<String, dynamic> booking) async {
    if (booking['table_id'] == null) {
      // Nessun tavolo auto-assegnato: fai scegliere il tavolo
      _assignBookingToTable(booking);
      return;
    }
    // Tavolo già assegnato: approva e invia email3
    await _supabase.from('bookings').update({'status': 'approved'}).eq('id', booking['id']);
    final guestId = booking['guest_id'];
    if (guestId != null) {
      try {
        await _supabase.rpc('increment_visits_count', params: {'guest_id': guestId});
      } catch (e) {
        debugPrint('increment_visits_count error: $e');
      }
    }
    _sendBookingAcceptedEmail(booking);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prenotazione accettata!'), backgroundColor: AppColors.accent),
    );
    _loadData();
  }

  Future<void> _rejectBooking(Map<String, dynamic> booking) async {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => RejectionScreen(
        booking: booking,
        onRejected: _loadData,
      ),
    ));
  }

  /// Email al cliente quando la prenotazione viene ACCETTATA.
  /// Nessun riferimento al tavolo: l'assegnazione è interna e modificabile.
  Future<void> _sendBookingAcceptedEmail(Map<String, dynamic> booking) async {
    final g = booking['guests'];
    final email = g?['email'] as String?;
    if (email == null || email.isEmpty) return;

    // Parsing internal_notes per turno e area
    String turno = '', area = '';
    try {
      final raw = booking['internal_notes'] as String? ?? '';
      if (raw.startsWith('{')) {
        final decoded = raw.replaceAll(RegExp(r'[\r\n]'), '');
        // simple extraction without dart:convert since it's already imported via supabase
        turno = _extractJson(decoded, 'turno');
        area = _extractJson(decoded, 'area');
      }
    } catch (_) {}

    try {
      await _supabase.functions.invoke('send-table-assigned-email', body: {
        'email': email,
        'nome': g?['first_name'] ?? '',
        'cognome': g?['surname'] ?? '',
        'phone': g?['phone'] ?? '',
        'date': booking['date'] ?? '',
        'time': (booking['time_start'] ?? '').toString().substring(0, 5),
        'persons': booking['party_size'] ?? 0,
        'notes': booking['notes'] ?? '',
        'turno': turno,
        'area': area,
        ...await datiRistorante(),
        'bookingId': booking['id'],
      });
    } catch (e) {
      debugPrint('send-table-assigned-email error: $e');
    }
  }

  String _extractJson(String json, String key) {
    final pattern = RegExp('"$key"\\s*:\\s*"([^"]*)"');
    return pattern.firstMatch(json)?.group(1) ?? '';
  }

  void _assignBookingToTable(Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        expand: false,
        builder: (_, sc) => Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Seleziona un tavolo libero',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(color: AppColors.divider),
          Expanded(
            child: SingleChildScrollView(
              controller: sc,
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10, runSpacing: 10,
                children: _tables.where((t) {
                  final status = _tableStatuses[t['id']] ?? TableStatus.free;
                  return status == TableStatus.free;
                }).map((t) {
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await _supabase.from('bookings').update({
                        'table_id': t['id'],
                        'status': 'approved',
                      }).eq('id', booking['id']);
                      final guestId = booking['guest_id'];
                      if (guestId != null) {
                        try {
                          await _supabase.rpc('increment_visits_count', params: {'guest_id': guestId});
                        } catch (e) {
                          debugPrint('increment_visits_count error: $e');
                        }
                      }
                      // Qui la prenotazione viene anche accettata, quindi l'email va inviata
                      _sendBookingAcceptedEmail(booking);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tavolo ${t['name']} assegnato!')),
                      );
                      _loadData();
                    },
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(t['name'].toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${t["capacity"]} posti',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
