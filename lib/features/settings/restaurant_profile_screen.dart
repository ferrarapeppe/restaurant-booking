import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

class RestaurantProfileScreen extends StatefulWidget {
  const RestaurantProfileScreen({super.key});
  @override
  State<RestaurantProfileScreen> createState() => _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  static const String _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _rulesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _addressCtrl.dispose(); _cityCtrl.dispose();
    _phoneCtrl.dispose(); _emailCtrl.dispose(); _websiteCtrl.dispose();
    _rulesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('restaurants')
          .select('*')
          .eq('id', _restaurantId)
          .single();
      _nameCtrl.text = res['name'] ?? '';
      _addressCtrl.text = res['address'] ?? '';
      _cityCtrl.text = res['city'] ?? '';
      _phoneCtrl.text = res['phone'] ?? '';
      _emailCtrl.text = res['email'] ?? '';
      _websiteCtrl.text = res['website'] ?? '';
      _rulesCtrl.text = res['booking_rules'] ?? '';
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _supabase.from('restaurants').update({
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'booking_rules': _rulesCtrl.text.trim(),
      }).eq('id', _restaurantId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo salvato'), backgroundColor: Color(0xFF2E7D52)),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profilo ristorante',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF2E7D52), strokeWidth: 2))
                : const Text('Salva', style: TextStyle(color: Color(0xFF2E7D52), fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D52)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar ristorante
                Center(
                  child: Column(children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB7182A),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Center(
                        child: Text('HIO', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Cambia logo'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Informazioni generali'),
                const SizedBox(height: 12),
                _ProfileField(label: 'Nome ristorante', controller: _nameCtrl, icon: Icons.restaurant_outlined),
                const SizedBox(height: 10),
                _ProfileField(label: 'Indirizzo', controller: _addressCtrl, icon: Icons.location_on_outlined),
                const SizedBox(height: 10),
                _ProfileField(label: 'Città', controller: _cityCtrl, icon: Icons.location_city_outlined),
                const SizedBox(height: 10),
                _ProfileField(label: 'Telefono', controller: _phoneCtrl, icon: Icons.phone_outlined, type: TextInputType.phone),
                const SizedBox(height: 10),
                _ProfileField(label: 'Email', controller: _emailCtrl, icon: Icons.email_outlined, type: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _ProfileField(label: 'Sito web', controller: _websiteCtrl, icon: Icons.language_outlined, type: TextInputType.url),
                const SizedBox(height: 24),
                const _SectionTitle('Regole di prenotazione'),
                const SizedBox(height: 8),
                const Text(
                  'Questo testo viene mostrato agli ospiti durante la prenotazione online.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: TextField(
                    controller: _rulesCtrl,
                    maxLines: 5,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Es: È possibile prenotare tavoli solo per cenare...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Bottone salva
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D52),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Salva profilo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
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
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
  );
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? type;
  const _ProfileField({required this.label, required this.controller, required this.icon, this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            TextField(
              controller: controller,
              keyboardType: type,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
