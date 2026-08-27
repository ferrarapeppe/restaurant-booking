import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/core/auth/accesso.dart';
import 'package:restaurant_booking/shared/widgets/logo_hio.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final profilo = statoAccesso.profilo;
    // Nascondere una voce non basta a proteggerla: il blocco vero e' nel
    // router. Qui si evita solo di mostrare porte che non si aprono.
    bool puo(String chiave) => profilo?.puoVedere(chiave) ?? false;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Intestazione nera col logo, come la barra in alto e il modulo.
              Container(
                color: AppColors.nero,
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                child: Column(
                  children: [
                    Row(children: [
                      IconButton(
                        icon: const Icon(Icons.menu_open, color: Colors.white, size: 26),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    const LogoHio(altezza: 84),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              const Divider(color: AppColors.divider),

              // Pannello di controllo
              if (puo('dashboard')) ...[
                _DrawerItem(icon: Icons.dashboard_outlined, label: 'Pannello di controllo', onTap: () { context.go('/'); Navigator.pop(context); }),
                const Divider(color: AppColors.divider, indent: 16, endIndent: 16),
              ],

              // Sezione prenotazioni
              if (puo('calendar'))
                _DrawerItem(icon: Icons.calendar_month_outlined, label: 'Calendario', onTap: () { context.go('/calendar'); Navigator.pop(context); }),
              if (puo('reservations'))
                _DrawerItem(icon: Icons.view_week_outlined, label: 'Programma', onTap: () { context.go('/reservations'); Navigator.pop(context); }),
              if (puo('bookings'))
                _DrawerItem(icon: Icons.list_alt_outlined, label: 'Elenco', onTap: () { context.go('/bookings'); Navigator.pop(context); }),
              if (puo('floor_plan'))
                _DrawerItem(icon: Icons.table_restaurant_outlined, label: 'Planimetria', onTap: () { Navigator.pop(context); context.go('/floor-plan/' + DateTime.now().toIso8601String().substring(0, 10)); }),
              const Divider(color: AppColors.divider, indent: 16, endIndent: 16),

              // Gestione
              if (puo('guests'))
                _DrawerItem(icon: Icons.people_outline, label: 'Clienti', onTap: () { context.go('/guests'); Navigator.pop(context); }),
              if (puo('reports'))
                _DrawerItem(icon: Icons.bar_chart_outlined, label: 'Rapporti', onTap: () { context.go('/reports'); Navigator.pop(context); }),
              if (puo('assistente'))
                _DrawerItem(icon: Icons.auto_awesome_outlined, label: 'Assistente', onTap: () { context.go('/assistente'); Navigator.pop(context); }),
              if (puo('settings'))
                _DrawerItem(icon: Icons.settings_outlined, label: 'Impostazioni', onTap: () { context.go('/settings'); Navigator.pop(context); }),
              const Divider(color: AppColors.divider),

              // Chi e' entrato, e come uscirne
              // A tutta larghezza: la colonna del menu centra i suoi figli, e
              // questo era l'unico a non allargarsi — quindi finiva in mezzo
              // mentre le voci qui sopra, che sono ListTile, riempiono la riga
              // e sembrano allineate a sinistra.
              if (profilo != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(profilo.nome.isEmpty ? profilo.email : profilo.nome,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(profilo.eAmministratore ? 'Amministratore' : 'Staff',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                ),
              _DrawerItem(
                icon: Icons.logout,
                label: 'Esci',
                onTap: () { Navigator.pop(context); statoAccesso.esci(); },
              ),
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
      leading: Icon(icon, color: AppColors.textPrimary, size: 24),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      minLeadingWidth: 28,
    );
  }
}
