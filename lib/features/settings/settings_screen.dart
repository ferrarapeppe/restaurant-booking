import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

// ── Settings Screen ───────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: Builder(builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFFB8860B)),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        )),
        title: const Text('Impostazioni', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Generale'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: [
              _SettingsCard(
                icon: Icons.access_time,
                title: 'Orari di apertura',
                description: 'Gestisci gli orari di apertura e aggiungi le impostazioni di gestione delle prenotazioni per orario di apertura.',
                onTap: () {},
              ),
              _SettingsCard(
                icon: Icons.chair_outlined,
                title: 'Tavoli',
                description: 'Imposta e gestisci le modalità di prenotazione dei tavoli e delle aree del tuo ristorante.',
                onTap: () => context.push('/settings/tables'),
              ),
              _SettingsCard(
                icon: Icons.dashboard_customize_outlined,
                title: 'Link e widget',
                description: 'Ottieni e gestisci il tuo link e widget di prenotazione online.',
                onTap: () {},
              ),
              _SettingsCard(
                icon: Icons.palette_outlined,
                title: 'Disegno',
                description: 'Modifica i colori, i caratteri e il layout del widget del flusso di prenotazione.',
                isPremium: true,
                premiumLabel: 'Aggiungi su. €7.99/mm',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Account'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: [
              _SettingsCard(
                icon: Icons.restaurant_outlined,
                title: 'Profilo ristorante',
                description: 'Modifica le informazioni del tuo ristorante visibili agli ospiti.',
                onTap: () {},
              ),
              _SettingsCard(
                icon: Icons.people_outline,
                title: 'Team',
                description: 'Gestisci i membri del team e i loro permessi.',
                onTap: () {},
              ),
              _SettingsCard(
                icon: Icons.notifications_outlined,
                title: 'Notifiche',
                description: 'Configura le notifiche per il personale e gli ospiti.',
                onTap: () {},
              ),
              _SettingsCard(
                icon: Icons.integration_instructions_outlined,
                title: 'Integrazioni',
                description: 'Connetti il tuo ristorante con altri servizi.',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
  );
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isPremium;
  final String? premiumLabel;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.isPremium = false,
    this.premiumLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AppColors.textPrimary, size: 40),
                  const SizedBox(height: 12),
                  Text(title, style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(description, style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
                  ),
                  if (isPremium && premiumLabel != null) ...[
                    const SizedBox(height: 8),
                    Text(premiumLabel!, style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ],
              ),
            ),
            if (isPremium)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: AppColors.textPrimary, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
