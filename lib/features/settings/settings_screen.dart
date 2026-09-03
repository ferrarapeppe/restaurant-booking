import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/azioni_barra.dart';
import 'package:restaurant_booking/shared/widgets/contenuto_centrato.dart';
import 'package:restaurant_booking/shared/widgets/pulsante_barra.dart';

// ── Settings Screen ───────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: const PulsanteBarra(),
        title: const Text('Impostazioni', style: TextStyle(color: AppColors.gold)),
        actions: [
          ...azioniBarra(context),
        ],
      ),
      body: LayoutBuilder(builder: (context, vincoli) {
        final colonne = colonnePerLarghezza(vincoli.maxWidth);
        return ContenutoCentrato(
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('Generale'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: colonne,
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
                onTap: () => context.push('/settings/opening-hours'),
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
                description: 'Il link da dare ai clienti e il codice per mettere il modulo dentro un sito.',
                onTap: () => context.push('/settings/link'),
              ),
              _SettingsCard(
                icon: Icons.notifications_active_outlined,
                title: 'Avvisi su Telegram',
                description: 'Chi riceve un messaggio quando arriva una prenotazione, e quali altri avvisi mandare.',
                onTap: () => context.push('/settings/telegram'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Account'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: colonne,
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
                onTap: () => context.push('/settings/profile'),
              ),
              _SettingsCard(
                icon: Icons.people_outline,
                title: 'Team',
                description: 'Gestisci i membri del team e i loro permessi.',
                onTap: () => context.push('/settings/team'),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
        );
      }),
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
  final VoidCallback onTap;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
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
        child: Padding(
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
                ],
              ),
        ),
      ),
    );
  }
}
