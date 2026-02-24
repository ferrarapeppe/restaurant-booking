import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_open, color: AppColors.textPrimary, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.local_fire_department, color: AppColors.accent, size: 24),
                  const SizedBox(width: 6),
                  const Text('Fenix Restaurant', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const Divider(color: AppColors.divider),
            _DrawerItem(icon: Icons.dashboard_outlined, label: 'Pannello di controllo', onTap: () { context.go('/'); Navigator.pop(context); }),
            const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
            _DrawerItem(icon: Icons.calendar_month_outlined, label: 'Calendario', onTap: () { context.go('/calendar'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.view_week_outlined, label: 'Programma', onTap: () { context.go('/bookings'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.list_alt_outlined, label: 'Elenco', onTap: () { context.go('/bookings'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.table_restaurant_outlined, label: 'Planimetria', onTap: () { Navigator.pop(context); }),
            const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
            _DrawerItem(icon: Icons.people_outline, label: 'Clienti', onTap: () { context.go('/guests'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.bar_chart_outlined, label: 'Rapporti', onTap: () { context.go('/reports'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.settings_outlined, label: 'Impostazioni', onTap: () { context.go('/settings'); Navigator.pop(context); }),
            const Spacer(),
            const Divider(color: AppColors.divider),
            _DrawerItem(icon: Icons.store_outlined, label: 'I tuoi ristoranti', onTap: () { Navigator.pop(context); }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      minLeadingWidth: 28,
    );
  }
}
