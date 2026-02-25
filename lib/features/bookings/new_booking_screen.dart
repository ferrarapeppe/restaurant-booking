import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';

class NewBookingScreen extends StatefulWidget {
  const NewBookingScreen({super.key});

  @override
  State<NewBookingScreen> createState() => _NewBookingScreenState();
}

class _NewBookingScreenState extends State<NewBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _internalNotesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  int _partySize = 2;
  String _selectedSource = 'phone';
  String? _selectedTable;
  bool _sendConfirmation = true;

  final List<String> _tables = ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _internalNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nuova prenotazione',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _submitForm,
            child: const Text('Salva', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sezione cliente
              _SectionTitle(title: 'Cliente'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _nameController,
                label: 'Nome e cognome *',
                icon: Icons.person_outline,
                validator: (v) => v!.isEmpty ? 'Campo obbligatorio' : null,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _phoneController,
                label: 'Telefono',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Sezione prenotazione
              _SectionTitle(title: 'Dettagli prenotazione'),
              const SizedBox(height: 12),

              // Data
              _buildTappableField(
                label: 'Data',
                icon: Icons.calendar_today_outlined,
                value: DateFormat('EEEE d MMMM yyyy', 'it_IT').format(_selectedDate),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2027),
                    locale: const Locale('it', 'IT'),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 10),

              // Orario
              _buildTappableField(
                label: 'Orario',
                icon: Icons.access_time,
                value: _selectedTime.format(context),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _selectedTime = picked);
                },
              ),
              const SizedBox(height: 10),

              // Numero ospiti
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_outline, color: AppColors.textSecondary, size: 22),
                    const SizedBox(width: 12),
                    const Text('Numero ospiti', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.accent),
                      onPressed: () => setState(() { if (_partySize > 1) _partySize--; }),
                    ),
                    Text('$_partySize',
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
                      onPressed: () => setState(() => _partySize++),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tavolo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.table_restaurant_outlined, color: AppColors.textSecondary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTable,
                          hint: const Text('Seleziona tavolo (opzionale)', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Nessun tavolo')),
                            ..._tables.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                          ],
                          onChanged: (v) => setState(() => _selectedTable = v),
                          isExpanded: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Sorgente
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.source_outlined, color: AppColors.textSecondary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSource,
                          items: const [
                            DropdownMenuItem(value: 'phone', child: Text('Telefono')),
                            DropdownMenuItem(value: 'web', child: Text('Web')),
                            DropdownMenuItem(value: 'walkin', child: Text('Walk-in')),
                            DropdownMenuItem(value: 'google', child: Text('Google')),
                          ],
                          onChanged: (v) => setState(() => _selectedSource = v!),
                          isExpanded: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Note
              _SectionTitle(title: 'Note'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _notesController,
                label: 'Richieste del cliente (visibili al cliente)',
                icon: Icons.chat_bubble_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _internalNotesController,
                label: 'Note interne (solo staff)',
                icon: Icons.lock_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Opzioni
              _SectionTitle(title: 'Opzioni'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SwitchListTile(
                  title: const Text('Invia conferma al cliente', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Email di conferma automatica', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  value: _sendConfirmation,
                  activeColor: AppColors.accent,
                  onChanged: (v) => setState(() => _sendConfirmation = v),
                ),
              ),
              const SizedBox(height: 32),

              // Bottone salva
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Crea prenotazione', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 22),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
      ),
    );
  }

  Widget _buildTappableField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 15)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prenotazione per ${_nameController.text} creata!'),
          backgroundColor: AppColors.accent,
        ),
      );
      Navigator.pop(context);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold));
  }
}
