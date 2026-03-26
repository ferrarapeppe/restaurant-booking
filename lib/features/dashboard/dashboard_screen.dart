import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/core/providers/booking_providers.dart';

const _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _loading = true;
  int _oggiPrenotazioni = 0;
  int _oggiOspiti = 0;
  int _settimanaPrenotazioni = 0;
  int _settimanaOspiti = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final oggi = DateTime.now();
      final oggiStr = DateFormat('yyyy-MM-dd').format(oggi);
      final tra7Str = DateFormat('yyyy-MM-dd').format(oggi.add(const Duration(days: 7)));

      // Query oggi
      final oggiRes = await supabase
          .from('bookings')
          .select('party_size')
          .eq('restaurant_id', _restaurantId)
          .eq('date', oggiStr)
          .inFilter('status', ['confirmed', 'pending']);

      // Query prossimi 7 giorni
      final settimanaRes = await supabase
          .from('bookings')
          .select('party_size')
          .eq('restaurant_id', _restaurantId)
          .gte('date', oggiStr)
          .lte('date', tra7Str)
          .inFilter('status', ['confirmed', 'pending']);

      int oggiOspiti = 0;
      for (final r in oggiRes) {
        oggiOspiti += (r['party_size'] as int? ?? 0);
      }

      int settimanaOspiti = 0;
      for (final r in settimanaRes) {
        settimanaOspiti += (r['party_size'] as int? ?? 0);
      }

      setState(() {
        _oggiPrenotazioni = oggiRes.length;
        _oggiOspiti = oggiOspiti;
        _settimanaPrenotazioni = settimanaRes.length;
        _settimanaOspiti = settimanaOspiti;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Dashboard stats error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oggi = DateFormat('d. MMM', 'it_IT').format(DateTime.now());
    final tra7 = DateFormat('d. MMM', 'it_IT').format(DateTime.now().add(const Duration(days: 7)));

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Image.asset('assets/images/logo_appbar.png', height: 34, fit: BoxFit.contain),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.textSecondary), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary), onPressed: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Scorciatoie', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _ShortcutButton(icon: Icons.calendar_today_outlined, label: 'Prenotazioni oggi', onTap: () {
                  final today = DateTime.now();
                  final dateStr = DateFormat('yyyy-MM-dd').format(today);
                  ref.read(selectedDateProvider.notifier).state = today;
                  context.go('/bookings?date=' + dateStr);
                }),
              const SizedBox(height: 8),
              _ShortcutButton(icon: Icons.calendar_month_outlined, label: 'Prenotazioni questo mese', onTap: () => context.go('/calendar')),
              const SizedBox(height: 8),
              _ShortcutButton(icon: Icons.settings_outlined, label: 'Impostazioni e componenti aggiuntivi', onTap: () => context.go('/settings')),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('Prenotazioni', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _StatsCard(
                label: 'Oggi',
                date: oggi,
                prenotazioni: _oggiPrenotazioni,
                ospiti: _oggiOspiti,
                loading: _loading,
              ),
              const SizedBox(height: 12),
              _StatsCard(
                label: 'Prossimi 7 giorni',
                date: '$oggi - $tra7',
                prenotazioni: _settimanaPrenotazioni,
                ospiti: _settimanaOspiti,
                loading: _loading,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/bookings/new'),
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
  final bool loading;
  const _StatsCard({required this.label, required this.date, required this.prenotazioni, required this.ospiti, this.loading = false});

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
                  loading
                    ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)))
                    : Text('$prenotazioni', style: const TextStyle(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.w300)),
                  const Text('Prenotazioni', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
              Container(width: 1, height: 50, color: AppColors.divider),
              Expanded(
                child: Column(children: [
                  loading
                    ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)))
                    : Text('$ospiti', style: const TextStyle(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.w300)),
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
