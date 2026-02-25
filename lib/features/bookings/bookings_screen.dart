import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

// Modello prenotazione
class Booking {
  final String id;
  final String guestName;
  final int partySize;
  final String time;
  final String status;
  final String? table;
  final String? notes;
  final String source;

  const Booking({
    required this.id,
    required this.guestName,
    required this.partySize,
    required this.time,
    required this.status,
    this.table,
    this.notes,
    this.source = 'web',
  });
}

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  DateTime _selectedDate = DateTime.now();
  String _filterStatus = 'tutti';

  // Dati mock
  final List<Booking> _bookings = [
    Booking(id: '1', guestName: 'Mario Rossi', partySize: 2, time: '12:30', status: 'confirmed', table: 'T1', source: 'web'),
    Booking(id: '2', guestName: 'Anna Bianchi', partySize: 4, time: '13:00', status: 'seated', table: 'T3', notes: 'Anniversario di matrimonio'),
    Booking(id: '3', guestName: 'Giuseppe Verdi', partySize: 3, time: '13:30', status: 'pending', source: 'phone'),
    Booking(id: '4', guestName: 'Laura Esposito', partySize: 6, time: '20:00', status: 'confirmed', table: 'T5', notes: 'Allergia ai crostacei'),
    Booking(id: '5', guestName: 'Carlo Ferrari', partySize: 2, time: '20:30', status: 'confirmed', source: 'google'),
    Booking(id: '6', guestName: 'Sofia Romano', partySize: 5, time: '21:00', status: 'noshow'),
    Booking(id: '7', guestName: 'Walk-in', partySize: 3, time: '21:15', status: 'walkin', table: 'T2'),
    Booking(id: '8', guestName: 'Marco Conti', partySize: 2, time: '21:30', status: 'left'),
  ];

  List<Booking> get _filteredBookings {
    if (_filterStatus == 'tutti') return _bookings;
    return _bookings.where((b) => b.status == _filterStatus).toList();
  }

  int get _totalGuests => _bookings.fold(0, (sum, b) => sum + b.partySize);

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE d MMMM yyyy', 'it_IT').format(_selectedDate);
    final capitalDate = dateStr[0].toUpperCase() + dateStr.substring(1);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2024),
              lastDate: DateTime(2027),
              locale: const Locale('it', 'IT'),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('d MMM yyyy', 'it_IT').format(_selectedDate),
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _StatChip(label: '${_bookings.length} prenotazioni', color: AppColors.accent),
                const SizedBox(width: 8),
                _StatChip(label: '$_totalGuests ospiti', color: AppColors.badgeGrey),
                const Spacer(),
                // Navigazione date
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                  onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Filtri stato
          Container(
            color: AppColors.surface,
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _FilterChip(label: 'Tutti', value: 'tutti', selected: _filterStatus == 'tutti', onTap: () => setState(() => _filterStatus = 'tutti')),
                _FilterChip(label: 'Confermati', value: 'confirmed', selected: _filterStatus == 'confirmed', onTap: () => setState(() => _filterStatus = 'confirmed')),
                _FilterChip(label: 'In attesa', value: 'pending', selected: _filterStatus == 'pending', onTap: () => setState(() => _filterStatus = 'pending')),
                _FilterChip(label: 'Seduti', value: 'seated', selected: _filterStatus == 'seated', onTap: () => setState(() => _filterStatus = 'seated')),
                _FilterChip(label: 'Partiti', value: 'left', selected: _filterStatus == 'left', onTap: () => setState(() => _filterStatus = 'left')),
                _FilterChip(label: 'No-show', value: 'noshow', selected: _filterStatus == 'noshow', onTap: () => setState(() => _filterStatus = 'noshow')),
                _FilterChip(label: 'Walk-in', value: 'walkin', selected: _filterStatus == 'walkin', onTap: () => setState(() => _filterStatus = 'walkin')),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Lista prenotazioni
          Expanded(
            child: _filteredBookings.isEmpty
                ? const Center(child: Text('Nessuna prenotazione', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredBookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final booking = _filteredBookings[index];
                      return _BookingCard(
                        booking: booking,
                        onStatusChange: (newStatus) {
                          setState(() {
                            final idx = _bookings.indexWhere((b) => b.id == booking.id);
                            if (idx != -1) {
                              _bookings[idx] = Booking(
                                id: booking.id,
                                guestName: booking.guestName,
                                partySize: booking.partySize,
                                time: booking.time,
                                status: newStatus,
                                table: booking.table,
                                notes: booking.notes,
                                source: booking.source,
                              );
                            }
                          });
                        },
                      );
                    },
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

  void _showNewBookingDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const _NewBookingSheet(),
    );
  }
}

// Card prenotazione
class _BookingCard extends StatelessWidget {
  final Booking booking;
  final Function(String) onStatusChange;

  const _BookingCard({required this.booking, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(booking.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusInfo['color'] as Color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Orario
            SizedBox(
              width: 48,
              child: Text(booking.time,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            // Info prenotazione
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(booking.guestName,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(width: 8),
                      Icon(Icons.people, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text('${booking.partySize}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (booking.table != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4)),
                          child: Text(booking.table!,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      _SourceIcon(source: booking.source),
                      if (booking.notes != null) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.note_outlined, size: 14, color: AppColors.textMuted),
                      ],
                    ],
                  ),
                  if (booking.notes != null) ...[
                    const SizedBox(height: 4),
                    Text(booking.notes!,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            // Status badge + menu
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (statusInfo['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusInfo['label'] as String,
                      style: TextStyle(color: statusInfo['color'] as Color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showStatusMenu(context),
                  child: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(booking.guestName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          for (final status in ['confirmed', 'seated', 'left', 'noshow', 'pending'])
            ListTile(
              leading: CircleAvatar(
                radius: 8,
                backgroundColor: _getStatusInfo(status)['color'] as Color,
              ),
              title: Text(_getStatusInfo(status)['label'] as String),
              onTap: () { onStatusChange(status); Navigator.pop(context); },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'confirmed': return {'label': 'Confermato', 'color': const Color(0xFF28A745)};
      case 'pending': return {'label': 'In attesa', 'color': const Color(0xFFFFC107)};
      case 'seated': return {'label': 'Seduto', 'color': const Color(0xFF007BFF)};
      case 'left': return {'label': 'Partito', 'color': const Color(0xFF6C757D)};
      case 'noshow': return {'label': 'No-show', 'color': const Color(0xFFDC3545)};
      case 'walkin': return {'label': 'Walk-in', 'color': const Color(0xFFFF8C00)};
      default: return {'label': status, 'color': AppColors.textSecondary};
    }
  }
}

class _SourceIcon extends StatelessWidget {
  final String source;
  const _SourceIcon({required this.source});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (source) {
      case 'google': icon = Icons.g_mobiledata; color = Colors.red; break;
      case 'phone': icon = Icons.phone; color = AppColors.textSecondary; break;
      case 'walkin': icon = Icons.directions_walk; color = Colors.orange; break;
      default: icon = Icons.language; color = AppColors.accent;
    }
    return Icon(icon, size: 16, color: color);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _NewBookingSheet extends StatelessWidget {
  const _NewBookingSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Nuova prenotazione', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Nome cliente', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Telefono', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Numero ospiti', prefixIcon: Icon(Icons.people_outline), border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Orario', prefixIcon: Icon(Icons.access_time), border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 12),
            const TextField(decoration: InputDecoration(labelText: 'Note', prefixIcon: Icon(Icons.note_outlined), border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Crea prenotazione', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
