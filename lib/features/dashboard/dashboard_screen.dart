import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final oggi = DateFormat('d. MMM', 'it_IT').format(DateTime.now());
    final tra7 = DateFormat('d. MMM', 'it_IT').format(DateTime.now().add(const Duration(days: 7)));

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.local_fire_department, color: AppColors.accent, size: 28),
            const SizedBox(width: 8),
            const Text('Fenix Restaurant', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Scorciatoie', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ShortcutButton(icon: Icons.calendar_today_outlined, label: 'Prenotazioni oggi', onTap: () => context.go('/bookings')),
            const SizedBox(height: 8),
            _ShortcutButton(icon: Icons.calendar_month_outlined, label: 'Prenotazioni questo mese', onTap: () => context.go('/calendar')),
            const SizedBox(height: 8),
            _ShortcutButton(icon: Icons.settings_outlined, label: 'Impostazioni e componenti aggiuntivi', onTap: () => context.go('/settings')),
            const SizedBox(height: 24),
            const Text('Prenotazioni', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _StatsCard(label: 'Oggi', date: oggi, prenotazioni: 0, ospiti: 0),
            const SizedBox(height: 12),
            _StatsCard(label: 'Prossimi 7 giorni', date: '$oggi - $tra7', prenotazioni: 0, ospiti: 0),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String label;
  final String date;
  final int prenotazioni;
  final int ospiti;
  const _StatsCard({required this.label, required this.date, required this.prenotazioni, required this.ospiti});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text(date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(children: [
                  Text('$prenotazioni', style: const TextStyle(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.w300)),
                  const Text('Prenotazioni', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
              Container(width: 1, height: 50, color: AppColors.divider),
              Expanded(
                child: Column(children: [
                  Text('$ospiti', style: const TextStyle(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.w300)),
                  const Text('Ospiti', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
