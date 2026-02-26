import 'package:flutter/material.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/features/bookings/bookings_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;
  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.booking.status;
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
    final statusInfo = _getStatusInfo(_status);
    final statusColor = statusInfo['color'] as Color;

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
          IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.accent), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: AppColors.textSecondary), onPressed: () => _showMoreMenu(context)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con nome e status
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border(left: BorderSide(color: statusColor, width: 5)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Text(
                      widget.booking.guestName.isNotEmpty ? widget.booking.guestName[0].toUpperCase() : '?',
                      style: TextStyle(color: statusColor, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.booking.guestName,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(statusInfo['label'] as String,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Azioni rapide stato
            Row(
              children: [
                _ActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'Confermato',
                  color: const Color(0xFF28A745),
                  active: _status == 'confirmed',
                  onTap: () => setState(() => _status = 'confirmed'),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.chair_outlined,
                  label: 'Seduto',
                  color: const Color(0xFF007BFF),
                  active: _status == 'seated',
                  onTap: () => setState(() => _status = 'seated'),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.logout,
                  label: 'Partito',
                  color: const Color(0xFF6C757D),
                  active: _status == 'left',
                  onTap: () => setState(() => _status = 'left'),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.cancel_outlined,
                  label: 'No-show',
                  color: const Color(0xFFDC3545),
                  active: _status == 'noshow',
                  onTap: () => setState(() => _status = 'noshow'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dettagli prenotazione
            _InfoCard(
              title: 'Prenotazione',
              children: [
                _InfoRow(icon: Icons.calendar_today_outlined, label: 'Data', value: '24 febbraio 2026'),
                _InfoRow(icon: Icons.access_time, label: 'Orario', value: widget.booking.time),
                _InfoRow(icon: Icons.people_outline, label: 'Ospiti', value: '${widget.booking.partySize} persone'),
                if (widget.booking.table != null)
                  _InfoRow(icon: Icons.table_restaurant_outlined, label: 'Tavolo', value: widget.booking.table!),
                _InfoRow(
                  icon: _sourceIcon(widget.booking.source),
                  label: 'Sorgente',
                  value: _sourceName(widget.booking.source),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contatti cliente
            _InfoCard(
              title: 'Cliente',
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Profilo completo', style: TextStyle(color: AppColors.accent, fontSize: 13)),
              ),
              children: [
                _InfoRow(icon: Icons.person_outline, label: 'Nome', value: widget.booking.guestName),
                _InfoRow(icon: Icons.phone_outlined, label: 'Telefono', value: '+39 091 123 4567'),
                _InfoRow(icon: Icons.email_outlined, label: 'Email', value: 'cliente@email.it'),
                _InfoRow(icon: Icons.history, label: 'Visite totali', value: '3 visite'),
              ],
            ),
            const SizedBox(height: 12),

            // Note
            if (widget.booking.notes != null)
              _InfoCard(
                title: 'Note cliente',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(widget.booking.notes!,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            _InfoCard(
              title: 'Note interne',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      const Text('Solo visibili allo staff',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic)),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Aggiungi', style: TextStyle(color: AppColors.accent, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bottone cancella
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(context),
                icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC3545)),
                label: const Text('Cancella prenotazione', style: TextStyle(color: Color(0xFFDC3545))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDC3545)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'phone': return Icons.phone_outlined;
      case 'google': return Icons.g_mobiledata;
      case 'walkin': return Icons.directions_walk;
      default: return Icons.language;
    }
  }

  String _sourceName(String source) {
    switch (source) {
      case 'phone': return 'Telefono';
      case 'google': return 'Google';
      case 'walkin': return 'Walk-in';
      default: return 'Web';
    }
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(leading: const Icon(Icons.edit_outlined, color: AppColors.accent), title: const Text('Modifica prenotazione'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.person_outline, color: AppColors.accent), title: const Text('Vai al profilo cliente'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.print_outlined, color: AppColors.textSecondary), title: const Text('Stampa'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.cancel_outlined, color: Color(0xFFDC3545)), title: const Text('Cancella', style: TextStyle(color: Color(0xFFDC3545))), onTap: () => Navigator.pop(context)),
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
        content: Text('Sei sicuro di voler cancellare la prenotazione di ${widget.booking.guestName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Cancella', style: TextStyle(color: Color(0xFFDC3545))),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? color : AppColors.divider, width: active ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? color : AppColors.textSecondary, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: active ? color : AppColors.textSecondary, fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _InfoCard({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...children,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }
}
