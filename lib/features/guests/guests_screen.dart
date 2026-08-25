import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/contenuto_centrato.dart';
import 'package:restaurant_booking/data/models/booking_model.dart';
import 'package:restaurant_booking/core/providers/guest_providers.dart';
import 'package:restaurant_booking/features/bookings/booking_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:restaurant_booking/features/guests/esporta_rubrica.dart';

class GuestsScreen extends ConsumerWidget {
  const GuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestsAsync = ref.watch(guestsProvider);
    final search = ref.watch(guestSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Clienti', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Esporta in rubrica',
            icon: const Icon(Icons.contact_phone_outlined, color: Colors.white70),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.nero,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => const SchedaEsportaRubrica(),
            ),
          ),
          IconButton(
            tooltip: 'Nuovo cliente',
            icon: const Icon(Icons.person_add_outlined, color: AppColors.gold),
            onPressed: () => _showAddGuestSheet(context, ref),
          ),
        ],
      ),
      body: ContenutoCentrato(larghezzaMassima: 1040,
      child: Column(
        children: [
          // Barra ricerca
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => ref.read(guestSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Cerca per nome, telefono, email...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () => ref.read(guestSearchProvider.notifier).state = '',
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // Stats
          guestsAsync.whenOrNull(
            data: (guests) => Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _StatChip(label: '${guests.length} clienti', color: AppColors.accent),
                  const SizedBox(width: 8),
                  _StatChip(
                    label: '${guests.where((g) => (g.tags).contains('vip')).length} VIP',
                    color: AppColors.gold,
                  ),
                ],
              ),
            ),
          ) ?? const SizedBox(),
          // Filtro dropdown
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              const Icon(Icons.filter_list, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: 'Tutto',
                dropdownColor: AppColors.surface,
                underline: Container(height: 1, color: AppColors.divider),
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'Tutto', child: Text('Tutto')),
                  DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                  DropdownMenuItem(value: 'Regular', child: Text('Regular')),
                  DropdownMenuItem(value: 'No-show', child: Text('No-show')),
                ],
                onChanged: (_) {},
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Aggiungi cliente'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
              ),
            ]),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Lista clienti
          Expanded(
            child: guestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (guests) => guests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            search.isNotEmpty ? 'Nessun risultato per "$search"' : 'Nessun cliente',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: guests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final guest = guests[index];
                        return _GuestCard(
                          guest: guest,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => GuestDetailScreen(guest: guest)),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGuestSheet(context, ref),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  void _showAddGuestSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AddGuestSheet(ref: ref),
    );
  }
}

class _GuestCard extends StatelessWidget {
  final GuestModel guest;
  final VoidCallback onTap;

  const _GuestCard({required this.guest, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isVip = guest.tags.contains('vip');
    final isNoShow = guest.tags.contains('no_show');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isVip ? AppColors.gold : AppColors.divider, width: isVip ? 1.5 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Avatar
            _GuestAvatar(name: guest.name, size: 48, isVip: isVip),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(guest.displayName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(width: 4),
                      const Text('😊', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      if (isVip) _TagBadge(label: 'VIP', color: AppColors.gold, textColor: AppColors.textPrimary),
                      if (isNoShow) _TagBadge(label: 'No-show', color: AppColors.accentLight, textColor: AppColors.accent),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (guest.phone != null) ...[
                        const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text(guest.phone!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => launchUrl(Uri.parse(_waUrl(guest.phone!)), mode: LaunchMode.externalApplication),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(5)),
                            child: const Icon(Icons.chat, size: 11, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (guest.email != null) ...[
                        const Icon(Icons.email_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Flexible(child: Text(guest.email!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Visite + tag
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${guest.visitsCount}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 18)),
                const Text('visite', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                if (guest.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final tag in guest.tags.take(3))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tag == 'vip'
                                ? AppColors.gold
                                : tag == 'no_show'
                                    ? AppColors.accentLight
                                    : AppColors.accentLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: tag == 'vip'
                                  ? AppColors.textPrimary
                                  : tag == 'no_show'
                                      ? AppColors.accent
                                      : AppColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (guest.tags.length > 3)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.cardLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${guest.tags.length - 3}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _TagBadge({required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
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

class _AddGuestSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddGuestSheet({required this.ref});

  @override
  State<_AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends State<_AddGuestSheet> {
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Set<String> _tags = {};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Nuovo cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            _buildField(_nameCtrl, 'Nome *', Icons.person_outline),
            const SizedBox(height: 10),
            _buildField(_surnameCtrl, 'Cognome', Icons.person_outline),
            const SizedBox(height: 10),
            _buildField(_phoneCtrl, 'Telefono', Icons.phone_outlined, type: TextInputType.phone),
            const SizedBox(height: 10),
            _buildField(_emailCtrl, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _buildField(_notesCtrl, 'Note', Icons.note_outlined, maxLines: 2),
            const SizedBox(height: 16),
            const Text('Tag', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final tag in ['vip', 'regular', 'no_show', 'allergie', 'compleanno'])
                  FilterChip(
                    label: Text(tag),
                    selected: _tags.contains(tag),
                    onSelected: (v) => setState(() => v ? _tags.add(tag) : _tags.remove(tag)),
                    selectedColor: AppColors.accentLight,
                    checkmarkColor: AppColors.accent,
                    labelStyle: TextStyle(color: _tags.contains(tag) ? AppColors.accent : AppColors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (_nameCtrl.text.isNotEmpty) {
                    await widget.ref.read(guestRepositoryProvider).createGuest(
                      name: _nameCtrl.text + (_surnameCtrl.text.isNotEmpty ? ' ' + _surnameCtrl.text : ''),
                      firstName: _nameCtrl.text.trim(),
                      surname: _surnameCtrl.text.trim(),
                      phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
                      email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
                      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
                      tags: _tags.toList(),
                    );
                    widget.ref.invalidate(guestsProvider);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Salva cliente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType? type, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
      ),
    );
  }
}

// Schermata dettaglio cliente
class GuestDetailScreen extends ConsumerStatefulWidget {
  final GuestModel guest;
  const GuestDetailScreen({super.key, required this.guest});

  @override
  ConsumerState<GuestDetailScreen> createState() => _GuestDetailScreenState();
}

class _GuestDetailScreenState extends ConsumerState<GuestDetailScreen> {
  List<BookingModel> _bookings = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      final bookings = await ref.read(guestRepositoryProvider).getGuestBookings(widget.guest.id);
      if (mounted) setState(() { _bookings = bookings; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.guest;
    final isVip = guest.tags.contains('vip');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(widget.guest.name, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.flag_outlined, color: Colors.white70), onPressed: () {}),
          IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white70), onPressed: () => _showEditGuestSheet(context)),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white70), onPressed: () {}),
          IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: ContenutoCentrato(larghezzaMassima: 900,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar grande centrale
            Center(
              child: Column(
                children: [
                  _GuestAvatar(name: guest.name, size: 80, isVip: isVip),
                  const SizedBox(height: 12),
                  if (isVip)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                      child: const Text('VIP', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Contatti
            _InfoCard(title: 'Contatti', children: [
              _InfoRow(icon: Icons.person_outline, label: 'Nome', value: guest.firstName ?? guest.name),
              if (guest.surname != null && guest.surname!.isNotEmpty)
                _InfoRow(icon: Icons.person_outline, label: 'Cognome', value: guest.surname!.toUpperCase()),
              if (guest.phone != null) _PhoneRow(phone: guest.phone!),
              if (guest.email != null) _InfoRow(icon: Icons.email_outlined, label: 'E-mail', value: guest.email!),
              if (guest.notes != null) _InfoRow(icon: Icons.note_outlined, label: 'Note', value: guest.notes!),
            ]),
            const SizedBox(height: 12),

            // Tag
            if (guest.tags.isNotEmpty) ...[
              _InfoCard(title: 'Tag', children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    children: guest.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(20)),
                      child: Text(tag, style: const TextStyle(color: AppColors.accent, fontSize: 13)),
                    )).toList(),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
            ],

            // Storico prenotazioni
            _InfoCard(
              title: 'Storico prenotazioni (${_loading ? "…" : "${_bookings.length}"})',
              children: _loading
                  ? [const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.accent)))]
                  : _loadError != null
                      ? [Padding(padding: const EdgeInsets.all(16), child: Text('Errore: $_loadError', style: const TextStyle(color: Colors.red)))]
                  : _bookings.isEmpty
                      ? [const Padding(padding: EdgeInsets.all(16), child: Text('Nessuna prenotazione', style: TextStyle(color: AppColors.textSecondary)))]
                      : _bookings.map((b) => InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)),
                          ),
                          child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: _statusColor(b.status), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${b.date.day}/${b.date.month}/${b.date.year} alle ${b.timeStart.substring(0, 5)}',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.people_outline, size: 13, color: AppColors.textSecondary),
                                  const SizedBox(width: 3),
                                  Text('${b.partySize} persone', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  if (b.tableId != null) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.table_restaurant_outlined, size: 13, color: AppColors.textSecondary),
                                    const SizedBox(width: 3),
                                    Text('Tavolo', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  ],
                                  if (b.notes != null) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.note_outlined, size: 13, color: AppColors.textSecondary),
                                    const SizedBox(width: 3),
                                    Flexible(child: Text(b.notes!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  ],
                                ]),
                              ],
                            )),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: _statusColor(b.status).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text(_statusLabel(b.status), style: TextStyle(color: _statusColor(b.status), fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(height: 4),
                                const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                              ],
                            ),
                          ]),
                        ))).toList(),
            ),
            const SizedBox(height: 24),

            // Bottone elimina
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Elimina cliente'),
                      content: Text('Eliminare "${guest.name}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await ref.read(guestRepositoryProvider).deleteGuest(guest.id);
                      ref.invalidate(guestsProvider);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Errore eliminazione: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Elimina cliente', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }

  void _showEditGuestSheet(BuildContext context) {
    final firstNameCtrl = TextEditingController(text: widget.guest.firstName ?? widget.guest.name);
    final surnameCtrl = TextEditingController(text: widget.guest.surname ?? '');
    final phoneCtrl = TextEditingController(text: widget.guest.phone ?? '');
    final emailCtrl = TextEditingController(text: widget.guest.email ?? '');
    final notesCtrl = TextEditingController(text: widget.guest.notes ?? '');
    final tags = Set<String>.from(widget.guest.tags);
    final newTagCtrl = TextEditingController();
    const predefinedTags = ['vip', 'regular', 'no_show', 'allergie', 'compleanno'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Modifica cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ]),
                const SizedBox(height: 16),
                _buildEditField(firstNameCtrl, 'Nome *', Icons.person_outline),
                const SizedBox(height: 10),
                _buildEditField(surnameCtrl, 'Cognome', Icons.person_outline),
                const SizedBox(height: 10),
                _buildEditField(phoneCtrl, 'Telefono', Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 10),
                _buildEditField(emailCtrl, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _buildEditField(notesCtrl, 'Note', Icons.note_outlined, maxLines: 2),
                const SizedBox(height: 16),
                const Text('Tag', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final tag in predefinedTags)
                      FilterChip(
                        label: Text(tag),
                        selected: tags.contains(tag),
                        onSelected: (v) => setState(() => v ? tags.add(tag) : tags.remove(tag)),
                        selectedColor: AppColors.accentLight,
                        checkmarkColor: AppColors.accent,
                        labelStyle: TextStyle(color: tags.contains(tag) ? AppColors.accent : AppColors.textSecondary),
                      ),
                    for (final tag in tags.where((t) => !predefinedTags.contains(t)))
                      Chip(
                        label: Text(tag),
                        onDeleted: () => setState(() => tags.remove(tag)),
                        backgroundColor: AppColors.goldLight,
                        labelStyle: const TextStyle(color: AppColors.gold, fontSize: 13),
                        deleteIconColor: AppColors.gold,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newTagCtrl,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Nuovo tag personalizzato...',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          prefixIcon: const Icon(Icons.label_outline, color: AppColors.textSecondary, size: 18),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                        ),
                        onSubmitted: (value) {
                          final tag = value.trim().toLowerCase();
                          if (tag.isNotEmpty) {
                            setState(() => tags.add(tag));
                            newTagCtrl.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final tag = newTagCtrl.text.trim().toLowerCase();
                        if (tag.isNotEmpty) {
                          setState(() => tags.add(tag));
                          newTagCtrl.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Aggiungi'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (firstNameCtrl.text.isNotEmpty) {
                        final firstName = firstNameCtrl.text.trim();
                        final surname = surnameCtrl.text.trim();
                        final fullName = surname.isNotEmpty ? '$firstName $surname' : firstName;
                        await ref.read(guestRepositoryProvider).updateGuest(
                          widget.guest.id,
                          name: fullName,
                          firstName: firstName,
                          surname: surname.isNotEmpty ? surname : '',
                          phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                          email: emailCtrl.text.isEmpty ? null : emailCtrl.text,
                          notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                          tags: tags.toList(),
                        );
                        ref.invalidate(guestsProvider);
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Salva modifiche', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(TextEditingController ctrl, String label, IconData icon, {TextInputType? type, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return AppColors.statoConfermato;
      case 'seated': return AppColors.statoAlTavolo;
      case 'left': return AppColors.statoConcluso;
      case 'no_show': return AppColors.statoAnnullato;
      default: return AppColors.gold;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved': return 'Confermato';
      case 'seated': return 'Seduto';
      case 'left': return 'Partito';
      case 'no_show': return 'No-show';
      default: return 'In attesa';
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        const Divider(height: 1, color: AppColors.divider),
        ...children,
      ]),
    );
  }
}

String _waUrl(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  final normalized = digits.startsWith('+') ? digits.substring(1) : digits.startsWith('0') ? digits.substring(1) : digits.length == 10 ? '39$digits' : digits;
  return 'https://wa.me/$normalized';
}

class _PhoneRow extends StatelessWidget {
  final String phone;
  const _PhoneRow({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.phone_outlined, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        const Text('Telefono', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(phone, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse(_waUrl(phone)), mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.chat, size: 16, color: Colors.white),
          ),
        ),
      ]),
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
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
      ]),
    );
  }
}

// ── Guest Avatar ──────────────────────────────────────────────────────────────
class _GuestAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool isVip;
  const _GuestAvatar({required this.name, required this.size, this.isVip = false});

  Color _colorFromName(String name) {
    final colors = [
      AppColors.textSecondary, AppColors.accent, AppColors.accent,
      AppColors.textSecondary, AppColors.textSecondary, AppColors.textSecondary,
    ];
    int hash = 0;
    for (final c in name.codeUnits) hash = (hash * 31 + c) & 0xFFFFFFFF;
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = isVip ? AppColors.textPrimary : _colorFromName(name);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
