import 'package:flutter/material.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final String? initialFilter;
  const BookingsScreen({super.key, this.initialDate, this.initialFilter});
  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  static const _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  final _supabase = Supabase.instance.client;
  String _statusFilter = 'attivo';
  String? _sourceFilter;
  List<Map<String, dynamic>> _bookingsWithDetails = [];
  bool _loading = false;

  final _statusOptions = [
    {'value': 'attivo', 'label': 'Attivo', 'icon': Icons.play_arrow},
    {'value': 'tutti', 'label': 'Qualsiasi stato', 'icon': Icons.filter_list},
    {'value': 'approved', 'label': 'Accettato', 'icon': Icons.thumb_up_outlined},
    {'value': 'pending', 'label': 'In attesa di conferma', 'icon': Icons.help_outline},
    {'value': 'seated', 'label': 'Accomodato', 'icon': Icons.chair_outlined},
    {'value': 'canceled', 'label': 'Annullato', 'icon': Icons.close},
    {'value': 'no_show', 'label': 'No-show', 'icon': Icons.block_outlined},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialDate != null) {
        ref.read(selectedDateProvider.notifier).state = widget.initialDate!;
      }
      if (widget.initialFilter == 'da_assegnare') {
        _statusFilter = 'pending';
        _sourceFilter = 'web';
      }
      _loadBookings();
    });
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    try {
      final date = ref.read(selectedDateProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      debugPrint('BOOKINGS LOAD date=$dateStr status=$_statusFilter');
      var query = _supabase
          .from('bookings')
          .select('*, guests(first_name, surname, name, phone, email), tables(name, capacity, area_id, areas(name))')
          .eq('restaurant_id', _restaurantId);
      if (_sourceFilter == 'web') {
        query = query.eq('source', 'web').eq('status', 'pending');
      } else {
        query = query.eq('date', dateStr);
        if (_statusFilter != 'tutti' && _statusFilter != 'attivo') {
          query = query.eq('status', _statusFilter);
        } else if (_statusFilter == 'attivo') {
          query = query.inFilter('status', ['approved', 'pending', 'seated']);
        }
      }

      final res = await query.order('time_start');
      debugPrint('BOOKINGS RESULT count=${res.length}');
      setState(() {
        _bookingsWithDetails = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('BOOKINGS ERROR: $e\n$st');
      setState(() => _loading = false);
    }
  }

  String _guestName(Map<String, dynamic> b) {
    final g = b['guests'];
    if (g == null) return 'Ospite';
    final fn = (g['first_name'] ?? '').toString().trim();
    final sn = (g['surname'] ?? '').toString().trim();
    if (fn.isNotEmpty || sn.isNotEmpty) return '$fn $sn'.trim().toUpperCase();
    return (g['name'] ?? 'Ospite').toString().toUpperCase();
  }


  void _changeDate(int delta) {
    final current = ref.read(selectedDateProvider);
    ref.read(selectedDateProvider.notifier).state = current.add(Duration(days: delta));
    _loadBookings();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime>(selectedDateProvider, (previous, next) {
      if (previous != next) _loadBookings();
    });

    final selectedDate = ref.watch(selectedDateProvider);
    final dayLabel = DateFormat('EEEE d MMM yyyy', 'it_IT').format(selectedDate);
    final capitalDay = dayLabel[0].toUpperCase() + dayLabel.substring(1);
    final total = _bookingsWithDetails.length;
    final totalGuests = _bookingsWithDetails.fold<int>(0, (s, b) => s + ((b['party_size'] as int?) ?? 0));
    final currentFilter = _statusOptions.firstWhere((s) => s['value'] == _statusFilter, orElse: () => _statusOptions[0]);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
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
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2027),
                  builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
                );
                if (picked != null) {
                  ref.read(selectedDateProvider.notifier).state = picked;
                  _loadBookings();
                }
              },
              child: Text(
                DateFormat('EEE d MMM', 'it_IT').format(selectedDate),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
              onPressed: () => _changeDate(1),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
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
      body: Column(children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(capitalDay, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF2E7D52), borderRadius: BorderRadius.circular(12)),
                child: const Text('Aperto', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.more_vert, color: AppColors.textSecondary), onPressed: () {}),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              GestureDetector(
                onTap: () => _showStatusFilter(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(currentFilter['icon'] as IconData, color: AppColors.textPrimary, size: 16),
                    const SizedBox(width: 6),
                    Text('${currentFilter['label']}  $total \u2022 $totalGuests',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_outlined, color: AppColors.textPrimary, size: 14),
                  SizedBox(width: 6),
                  Text('Tutto il giorno', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Totale $total \u2022 $totalGuests',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          child: const Row(children: [
            SizedBox(width: 72, child: Padding(padding: EdgeInsets.only(left: 8), child: Text('Ora', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)))),
            Expanded(child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Nome', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)))),
            SizedBox(width: 36, child: Center(child: Text('P', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)))),
            SizedBox(width: 86, child: Padding(padding: EdgeInsets.only(left: 4), child: Text('Tavolo/i', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)))),
            SizedBox(width: 70, child: Center(child: Text('Stato', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)))),
          ]),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D52)))
              : _bookingsWithDetails.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.event_busy, size: 64, color: AppColors.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        const Text('Nessuna prenotazione', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                      ]),
                    )
                  : ListView.separated(
                      itemCount: _bookingsWithDetails.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final b = _bookingsWithDetails[index];
                        return _BookingRow(
                          booking: b,
                          guestName: _guestName(b),
                          onTap: () => _showBookingDetail(context, b),
                          onStatusChange: (newStatus) async {
                            await _supabase.from('bookings')
                                .update({'status': newStatus}).eq('id', b['id']);
                            _loadBookings();
                          },
                          onReject: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => RejectionScreen(
                              booking: b,
                              onRejected: _loadBookings,
                            ),
                          )),
                        );
                      },
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/bookings/new'),
        backgroundColor: const Color(0xFF2E7D52),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showStatusFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _statusOptions.map((opt) {
          final isSelected = _statusFilter == opt['value'];
          return ListTile(
            leading: Icon(opt['icon'] as IconData,
                color: isSelected ? const Color(0xFF2E7D52) : AppColors.textSecondary),
            title: Text(opt['label'] as String,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF2E7D52) : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
            trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF2E7D52)) : null,
            onTap: () {
              setState(() => _statusFilter = opt['value'] as String);
              Navigator.pop(context);
              _loadBookings();
            },
          );
        }).toList(),
      ),
    );
  }

  void _showBookingDetail(BuildContext context, Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => BookingDetailSheet(
        booking: booking,
        onSaved: () { Navigator.pop(context); _loadBookings(); },
      ),
    );
  }

}
// ── Status menu items ─────────────────────────────────────────────────────────
const _kStatusChoices = [
  ('pending',   'Richiesta',          Icons.help_outline),
  ('approved',  'Accettato',          Icons.thumb_up_outlined),
  ('seated',    'Accomodato',         Icons.chair_outlined),
  ('left',      'Se ne è andato',     Icons.done_all),
  ('no_show',   'No-show',            Icons.block_outlined),
  ('canceled',  'Annullato',          Icons.close),
  ('rejected',  'Rifiuta (con email)',Icons.thumb_down_outlined),
];

Color _statusDotColor(String status) {
  switch (status) {
    case 'approved': return const Color(0xFFFFC107);
    case 'seated':   return const Color(0xFF2E7D52);
    case 'left':     return Colors.grey;
    case 'canceled':
    case 'no_show':  return Colors.red;
    case 'pending':  return const Color(0xFFFFC107);
    default:         return AppColors.textMuted;
  }
}

// ── Booking Row ───────────────────────────────────────────────────────────────
class _BookingRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String guestName;
  final VoidCallback onTap;
  final Future<void> Function(String)? onStatusChange;
  final VoidCallback? onReject;

  const _BookingRow({
    required this.booking,
    required this.guestName,
    required this.onTap,
    this.onStatusChange,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final timeStart = (booking['time_start'] ?? '').toString().substring(0, 5);
    final timeEnd = booking['time_end'] != null
        ? booking['time_end'].toString().substring(0, 5)
        : '';
    final partySize = booking['party_size'] as int? ?? 0;
    final status = booking['status'] as String? ?? '';
    final table = booking['tables'] as Map<String, dynamic>?;
    final tableName = table?['name']?.toString() ?? '';
    final areaName =
        (table?['areas'] as Map<String, dynamic>?)?['name']?.toString() ?? '';
    final isPending = status == 'pending';

    return GestureDetector(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Colonna ora — teal
          Container(
            width: 72,
            color: const Color(0xFF00897B),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(timeStart,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                if (timeEnd.isNotEmpty)
                  Text(timeEnd,
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          // Nome
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(guestName,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
          ),
          // Party size circle (P)
          SizedBox(
            width: 36,
            child: Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: partySize >= 3
                      ? const Color(0xFFE6781A)
                      : Colors.transparent,
                  border: partySize < 3
                      ? Border.all(
                          color: const Color(0xFFE6781A).withValues(alpha: 0.7))
                      : null,
                ),
                child: Center(
                  child: Text('$partySize',
                      style: TextStyle(
                          color: partySize >= 3
                              ? Colors.white
                              : const Color(0xFFE6781A),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
          // Tavolo/i
          SizedBox(
            width: 86,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: tableName.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (areaName.isNotEmpty)
                          Text(areaName.toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF4A5568)),
                          child: Center(
                            child: Text(tableName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Text('—',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 14))),
            ),
          ),
          // Stato — pulsanti per pending, popup per gli altri
          SizedBox(
            width: 70,
            child: isPending
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    GestureDetector(
                      onTap: () => onStatusChange?.call('approved'),
                      child: Container(
                        width: 30, height: 30,
                        decoration: const BoxDecoration(
                            color: Color(0xFF2E7D52), shape: BoxShape.circle),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 17),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onReject,
                      child: Container(
                        width: 30, height: 30,
                        decoration: const BoxDecoration(
                            color: Color(0xFFDC3545), shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 17),
                      ),
                    ),
                  ])
                : PopupMenuButton<String>(
                    color: AppColors.surface,
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'rejected') {
                        onReject?.call();
                      } else {
                        onStatusChange?.call(value);
                      }
                    },
                    itemBuilder: (_) => _kStatusChoices.map((choice) {
                      final isCurrent = choice.$1 == status;
                      return PopupMenuItem<String>(
                        value: choice.$1 == 'rejected' ? 'rejected' : choice.$1,
                        child: Container(
                          color: isCurrent
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Icon(choice.$3,
                                size: 18,
                                color: isCurrent
                                    ? AppColors.accent
                                    : AppColors.textPrimary),
                            const SizedBox(width: 10),
                            Text(choice.$2,
                                style: TextStyle(
                                    color: isCurrent
                                        ? AppColors.accent
                                        : AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                          ]),
                        ),
                      );
                    }).toList(),
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _statusDotColor(status)),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down,
                            size: 14, color: AppColors.textMuted),
                      ]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ── Booking Detail Sheet ──────────────────────────────────────────────────────
class BookingDetailSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onSaved;
  const BookingDetailSheet({required this.booking, required this.onSaved});

  @override
  State<BookingDetailSheet> createState() => _BookingDetailSheetState();
}

class _BookingDetailSheetState extends State<BookingDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  late TextEditingController _nomeCtrl, _cognomeCtrl, _phoneCtrl, _emailCtrl, _noteCtrl, _msgCtrl;
  late DateTime _editDate;
  late String _editTime;
  late int _editPartySize;
  late String _editStatus, _editSource;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final b = widget.booking;
    _editDate = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
    _editTime = b['time_start']?.toString().substring(0, 5) ?? '20:00';
    _editPartySize = (b['party_size'] as int?) ?? 2;
    _editStatus = (b['status'] as String?) ?? 'approved';
    _editSource = (b['source'] as String?) ?? 'phone';
    final g = b['guests'];
    _nomeCtrl = TextEditingController(text: (g?['first_name'] ?? '').toString());
    _cognomeCtrl = TextEditingController(text: (g?['surname'] ?? '').toString().toUpperCase());
    _phoneCtrl = TextEditingController(text: (g?['phone'] ?? '').toString());
    _emailCtrl = TextEditingController(text: (g?['email'] ?? '').toString());
    _noteCtrl = TextEditingController(text: (b['notes'] ?? '').toString());
    _msgCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeCtrl.dispose(); _cognomeCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _noteCtrl.dispose(); _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final guestId = widget.booking['guest_id'];
      if (guestId != null) {
        await _supabase.from('guests').update({
          'first_name': _nomeCtrl.text.trim(),
          'surname': _cognomeCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
        }).eq('id', guestId);
      }
      final dateStr = DateFormat('yyyy-MM-dd').format(_editDate);
      await _supabase.from('bookings').update({
        'date': dateStr,
        'time_start': '$_editTime:00',
        'party_size': _editPartySize,
        'status': _editStatus,
        'source': _editSource,
        'notes': _noteCtrl.text.trim(),
      }).eq('id', widget.booking['id']);
      widget.onSaved();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prenotazione salvata'), backgroundColor: AppColors.accent),
      );
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

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE d MMM yyyy', 'it_IT').format(_editDate);
    final t = widget.booking['tables'];
    final tableName = t?['name']?.toString() ?? '';
    final tableCapacity = t?['capacity']?.toString() ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (_, sc) => Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.textPrimary, unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1),
          tabs: const [Tab(text: 'DETTAGLI'), Tab(text: 'MESSAGGI, NOTE')],
        ),
        Expanded(
          child: TabBarView(controller: _tabController, children: [
            ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              _DetailRow(label: 'Data', child: Row(children: [
                Expanded(child: Text(_cap(dateLabel), style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                IconButton(icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 20),
                    onPressed: () => setState(() => _editDate = _editDate.subtract(const Duration(days: 1)))),
                IconButton(icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
                    onPressed: () => setState(() => _editDate = _editDate.add(const Duration(days: 1)))),
              ])),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Ora', child: Row(children: [
                Expanded(child: Text(_editTime, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 20), onPressed: () => _changeTime(-15)),
                IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 20), onPressed: () => _changeTime(15)),
              ])),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Persone', child: Row(children: [
                Expanded(child: Text('$_editPartySize', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16))),
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 20),
                    onPressed: () => setState(() => _editPartySize = (_editPartySize - 1).clamp(1, 20))),
                IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.textSecondary, size: 20),
                    onPressed: () => setState(() => _editPartySize = (_editPartySize + 1).clamp(1, 20))),
              ])),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Tavolo', child: tableName.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: Text(
                      tableCapacity.isNotEmpty ? '$tableName  ($tableCapacity posti)' : tableName,
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  )
                : const Text('Nessun tavolo assegnato',
                    style: TextStyle(color: Color(0xFFFFC107), fontSize: 14))),
              const SizedBox(height: 16),
              _EditableField(label: 'Nome', controller: _nomeCtrl),
              const SizedBox(height: 8),
              _EditableField(label: 'Telefono', controller: _phoneCtrl, prefix: 'Italy (+39)', type: TextInputType.phone),
              const SizedBox(height: 8),
              _EditableField(label: 'E-mail', controller: _emailCtrl, type: TextInputType.emailAddress),
              const SizedBox(height: 8),
              _EditableField(label: 'Cognome', controller: _cognomeCtrl),
              const SizedBox(height: 16),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Stato', child: DropdownButton<String>(
                value: _editStatus,
                dropdownColor: AppColors.surface,
                underline: const SizedBox(), isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'approved', child: Text('👍 Accettato', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'seated', child: Text('🍽️ Al tavolo', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'pending', child: Text('❓ In attesa', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'canceled', child: Text('✕ Annullato', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'no_show', child: Text('🚫 No-show', style: TextStyle(color: AppColors.textPrimary))),
                ],
                onChanged: (v) => setState(() => _editStatus = v!),
              )),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Sorgente', child: DropdownButton<String>(
                value: _editSource,
                dropdownColor: AppColors.surface,
                underline: const SizedBox(), isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'phone', child: Text('📞 Telefono', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'web', child: Text('🌐 Web', style: TextStyle(color: AppColors.textPrimary))),
                  DropdownMenuItem(value: 'walkin', child: Text('🚶 Walk-in', style: TextStyle(color: AppColors.textPrimary))),
                ],
                onChanged: (v) => setState(() => _editSource = v!),
              )),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Note', child: TextField(
                controller: _noteCtrl, maxLines: 3,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              )),
              const SizedBox(height: 20),
            ]),
            Column(children: [
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
                Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Prenotazione creata', style: TextStyle(color: AppColors.textPrimary))),
              ])),
              Container(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Nota interna...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none, isDense: true,
                    ),
                  )),
                  const Icon(Icons.send, color: AppColors.textSecondary, size: 20),
                ]),
              ),
            ]),
          ]),
        ),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (widget.booking['status'] == 'pending') ...[
              ElevatedButton.icon(
                onPressed: () async {
                  final supabase = Supabase.instance.client;
                  await supabase.from('bookings').update({'status': 'approved'}).eq('id', widget.booking['id']);
                  sendTableAssignedEmail(widget.booking, widget.booking['tables'] as Map<String, dynamic>? ?? {});
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  widget.onSaved();
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Accetta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D52),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => RejectionScreen(
                      booking: widget.booking,
                      onRejected: widget.onSaved,
                    ),
                  ));
                },
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Rifiuta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC3545),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            _ActionBtn(icon: Icons.more_horiz, onTap: () {}),
            const SizedBox(width: 12),
            _ActionBtn(icon: Icons.close, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 12),
            _saving
                ? const CircularProgressIndicator(color: Color(0xFF2E7D52))
                : _ActionBtn(icon: Icons.check, color: AppColors.accent, onTap: _save),
          ]),
        ),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label; final Widget child;
  const _DetailRow({required this.label, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 4), child,
    ]),
  );
}

class _EditableField extends StatelessWidget {
  final String label; final TextEditingController controller;
  final String? prefix; final TextInputType? type;
  const _EditableField({required this.label, required this.controller, this.prefix, this.type});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    decoration: BoxDecoration(color: AppColors.cardLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      const SizedBox(height: 2),
      Row(children: [
        if (prefix != null) ...[
          Text(prefix!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 6),
        ],
        Expanded(child: TextField(controller: controller, keyboardType: type,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
      ]),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color? color;
  const _ActionBtn({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(color: color ?? AppColors.divider, shape: BoxShape.circle),
      child: Icon(icon, color: AppColors.textPrimary, size: 22),
    ),
  );
}

// ── BookingCard (public widget usato da ReservationsScreen) ──────────────────
class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final Future<void> Function(String status) onStatusChange;

  const BookingCard({super.key, required this.booking, required this.onStatusChange});

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return const Color(0xFF28A745);
      case 'pending':   return const Color(0xFFFFC107);
      case 'seated':    return const Color(0xFF007BFF);
      case 'left':      return const Color(0xFF6C757D);
      case 'no_show':    return const Color(0xFFDC3545);
      case 'walkin':    return const Color(0xFFFF8C00);
      default:          return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStart = booking.timeStart.length >= 5 ? booking.timeStart.substring(0, 5) : booking.timeStart;
    final partySize = booking.partySize;
    final statusColor = _statusColor(booking.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        SizedBox(
          width: 48,
          child: Text(timeStart,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(booking.guestName,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textSecondary.withOpacity(0.5)),
          ),
          child: Center(
            child: Text('$partySize',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
      ]),
    );
  }
}

Future<void> sendTableAssignedEmail(
  Map<String, dynamic> booking,
  Map<String, dynamic> table,
) async {
  final g = booking['guests'];
  final email = g?['email'] as String?;
  if (email == null || email.isEmpty) return;

  String turno = '', area = '';
  try {
    final raw = booking['internal_notes'] as String? ?? '';
    if (raw.startsWith('{')) {
      final pattern = RegExp(r'"(\w+)"\s*:\s*"([^"]*)"');
      for (final m in pattern.allMatches(raw)) {
        if (m.group(1) == 'turno') turno = m.group(2) ?? '';
        if (m.group(1) == 'area') area = m.group(2) ?? '';
      }
    }
  } catch (_) {}

  try {
    final guestId = booking['guest_id'];
    if (guestId != null) {
      try {
        await Supabase.instance.client.rpc('increment_visits_count', params: {'guest_id': guestId});
      } catch (_) {}
    }
    await Supabase.instance.client.functions.invoke('send-table-assigned-email', body: {
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
      'tableName': table['name']?.toString() ?? '',
      'restaurantName': 'Hio Oriental Bar',
      'restaurantAddress': 'Via Giuseppe Mazzini 5',
      'restaurantCity': '90139 Palermo',
      'restaurantPhone': '+39 328 574 4906',
      'restaurantEmail': 'info@hiooriental.com',
      'bookingId': booking['id'],
    });
  } catch (e) {
    debugPrint('send-table-assigned-email error: $e');
  }
}

// ── Rejection Screen ──────────────────────────────────────────────────────────
class RejectionScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onRejected;
  const RejectionScreen({super.key, required this.booking, required this.onRejected});
  @override
  State<RejectionScreen> createState() => _RejectionScreenState();
}

class _RejectionScreenState extends State<RejectionScreen> {
  static const _motivi = [
    ('Al completo', 'Siamo al completo. Possiamo proporti un giorno o un orario diverso?'),
    ('Chiuso', 'Quel giorno saremo chiusi. Possiamo proporti un giorno diverso?'),
    ('Altro', 'Purtroppo non possiamo accettare la tua prenotazione perché'),
  ];

  String _selectedMotivo = 'Al completo';
  late TextEditingController _msgCtrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController(text: _motivi[0].$2);
  }

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  void _onMotivoChanged(String? value) {
    if (value == null) return;
    final match = _motivi.firstWhere((m) => m.$1 == value, orElse: () => _motivi[0]);
    setState(() {
      _selectedMotivo = value;
      _msgCtrl.text = match.$2;
    });
  }

  Future<void> _confirm() async {
    setState(() => _sending = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('bookings').update({'status': 'canceled'}).eq('id', widget.booking['id']);
      final g = widget.booking['guests'];
      final email = g?['email'] as String? ?? '';
      if (email.isNotEmpty) {
        try {
          await supabase.functions.invoke('send-rejection-email', body: {
            'email': email,
            'nome': g?['first_name'] ?? '',
            'cognome': g?['surname'] ?? '',
            'motivo': _selectedMotivo,
            'messaggio': _msgCtrl.text.trim(),
            'restaurantName': 'Hio Oriental Bar',
          });
        } catch (e) { debugPrint('send-rejection-email error: $e'); }
      }
      if (mounted) { Navigator.pop(context); widget.onRejected(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Perché rifiuti la prenotazione?',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Invia un messaggio all\'ospite o utilizza uno dei nostri messaggi standard in base al motivo.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 32),
            // Dropdown Motivo
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2E7D52), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text('Motivo', style: TextStyle(color: Color(0xFF2E7D52), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                DropdownButton<String>(
                  value: _selectedMotivo,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  items: _motivi.map((m) => DropdownMenuItem(
                    value: m.$1,
                    child: Text(m.$1, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                  )).toList(),
                  onChanged: _onMotivoChanged,
                ),
              ]),
            ),
            const SizedBox(height: 16),
            // Messaggio editabile
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text('Messaggio all\'utente', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(12, 4, 12, 12),
                  ),
                ),
              ]),
            ),
            const Spacer(),
            Row(children: [
              ElevatedButton.icon(
                onPressed: _sending ? null : _confirm,
                icon: const Icon(Icons.thumb_down, size: 18),
                label: const Text('Rifiuta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D52),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
