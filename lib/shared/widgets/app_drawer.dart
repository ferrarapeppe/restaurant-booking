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
        child: SingleChildScrollView(
          child: Column(
            children: [
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_open, color: AppColors.textPrimary, size: 26),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                              ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(color: Color(0xFFC9B06E).withOpacity(0.4), blurRadius: 30, spreadRadius: 10),
                      ],
                    ),
                    child: Image.asset('assets/images/logo_drawer.png', height: 60, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const Divider(color: AppColors.divider),
            _DrawerItem(icon: Icons.dashboard_outlined, label: 'Pannello di controllo', onTap: () { context.go('/'); Navigator.pop(context); }),
            const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
            _DrawerItem(icon: Icons.calendar_month_outlined, label: 'Calendario', onTap: () { context.go('/calendar'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.calendar_today_outlined, label: 'Prenotazioni', onTap: () { context.go('/reservations'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.view_week_outlined, label: 'Programma', onTap: () { context.go('/bookings'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.list_alt_outlined, label: 'Elenco', onTap: () { context.go('/bookings'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.table_restaurant_outlined, label: 'Planimetria', onTap: () { Navigator.pop(context); context.go('/floorplan'); }),
            const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
            _DrawerItem(icon: Icons.people_outline, label: 'Clienti', onTap: () { context.go('/guests'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.bar_chart_outlined, label: 'Rapporti', onTap: () { context.go('/reports'); Navigator.pop(context); }),
            _DrawerItem(icon: Icons.settings_outlined, label: 'Impostazioni', onTap: () { context.go('/settings'); Navigator.pop(context); }),
            const Divider(color: AppColors.divider),
            _DrawerItem(icon: Icons.store_outlined, label: 'I tuoi ristoranti', onTap: () { Navigator.pop(context); }),
            const SizedBox(height: 16),
            ],
          ),
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
      title: Text(label, style: const TextStyle(color: AppColors.gold, fontSize: 15)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      minLeadingWidth: 28,
    );
  }
}
