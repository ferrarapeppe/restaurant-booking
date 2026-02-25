import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/features/bookings/bookings_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;
  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.booking.status;
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

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(_currentStatus);
    final booking = widget.booking;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Dettaglio prenotazione',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card principale
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border(left: BorderSide(color: statusInfo['color'] as Color, width: 5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(booking.guestName,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (statusInfo['color'] as Color).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(statusInfo['label'] as String,
                            style: TextStyle(color: statusInfo['color'] as Color, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.access_time, label: 'Orario', value: booking.time),
                  _InfoRow(icon: Icons.people_outline, label: 'Ospiti', value: '${booking.partySize} persone'),
                  if (booking.table != null)
                    _InfoRow(icon: Icons.table_restaurant_outlined, label: 'Tavolo', value: booking.table!),
                  _InfoRow(
                    icon: Icons.source_outlined,
                    label: 'Sorgente',
                    value: _getSourceLabel(booking.source),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cambio stato rapido
            const Text('Cambia stato', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _StatusButton(label: 'Confermato', status: 'confirmed', current: _currentStatus, onTap: () => setState(() => _currentStatus = 'confirmed')),
                  _StatusButton(label: 'Seduto', status: 'seated', current: _currentStatus, onTap: () => setState(() => _currentStatus = 'seated')),
                  _StatusButton(label: 'Partito', status: 'left', current: _currentStatus, onTap: () => setState(() => _currentStatus = 'left')),
                  _StatusButton(label: 'No-show', status: 'noshow', current: _currentStatus, onTap: () => setState(() => _currentStatus = 'noshow')),
                  _StatusButton(label: 'In attesa', status: 'pending', current: _currentStatus, onTap: () => setState(() => _currentStatus = 'pending')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Contatti cliente
            const Text('Contatti', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _ContactRow(icon: Icons.phone_outlined, label: '+39 091 123456', onTap: () {}),
                  const Divider(color: AppColors.divider, height: 16),
                  _ContactRow(icon: Icons.email_outlined, label: 'cliente@email.it', onTap: () {}),
                  const Divider(color: AppColors.divider, height: 16),
                  _ContactRow(icon: Icons.chat_outlined, label: 'Invia messaggio', onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Note cliente
            if (booking.notes != null) ...[
              const Text('Richieste cliente', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(booking.notes!, style: const TextStyle(color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 16),
            ],

            // Note interne
            const Text('Note interne', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBE6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE58F)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Color(0xFFD48806), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Nessuna nota interna',
                        style: TextStyle(color: Color(0xFF8C6914), fontStyle: FontStyle.italic)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFFD48806), size: 20),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Storico cliente
            const Text('Storico cliente', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  _StatsBox(value: '3', label: 'Visite'),
                  _StatsBox(value: '0', label: 'No-show'),
                  _StatsBox(value: 'Regular', label: 'Tipo'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Azioni
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancelDialog(context),
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    label: const Text('Cancella', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _currentStatus = 'seated'),
                    icon: const Icon(Icons.chair_outlined, color: Colors.white),
                    label: const Text('Segna seduto', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007BFF),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'phone': return 'Telefono';
      case 'web': return 'Web';
      case 'google': return 'Google';
      case 'walkin': return 'Walk-in';
      default: return source;
    }
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          ListTile(leading: const Icon(Icons.print_outlined), title: const Text('Stampa'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.copy_outlined), title: const Text('Duplica prenotazione'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.flag_outlined, color: Colors.red), title: const Text('Segna no-show', style: TextStyle(color: Colors.red)), onTap: () { setState(() => _currentStatus = 'noshow'); Navigator.pop(context); }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancella prenotazione'),
        content: const Text('Sei sicuro di voler cancellare questa prenotazione?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancella', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          const Spacer(),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final String status;
  final String current;
  final VoidCallback onTap;
  const _StatusButton({required this.label, required this.status, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = status == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _StatsBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatsBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
