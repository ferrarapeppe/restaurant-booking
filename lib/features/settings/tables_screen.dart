import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/shared/widgets/azioni_barra.dart';
import 'package:restaurant_booking/shared/widgets/contenuto_centrato.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});
  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> with SingleTickerProviderStateMixin {
  static const String _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  List<Map<String, dynamic>> _areas = [];
  Map<String, List<Map<String, dynamic>>> _tablesByArea = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final areas = await _supabase
          .from('areas')
          .select('*')
          .eq('restaurant_id', _restaurantId)
          .order('sort_order');
      final tables = await _supabase
          .from('tables')
          .select('*')
          .eq('restaurant_id', _restaurantId)
          .order('name');

      final byArea = <String, List<Map<String, dynamic>>>{};
      for (final a in areas) {
        byArea[a['id']] = (tables as List)
            .where((t) => t['area_id'] == a['id'])
            .map((t) => Map<String, dynamic>.from(t))
            .toList();
      }
      setState(() {
        _areas = List<Map<String, dynamic>>.from(areas);
        _tablesByArea = byArea;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addArea() async {
    final nameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _InputDialog(
        title: 'Nuova area',
        label: 'Nome area',
        controller: nameCtrl,
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      await _supabase.from('areas').insert({
        'restaurant_id': _restaurantId,
        'name': nameCtrl.text.trim(),
        'sort_order': _areas.length,
      });
      _loadData();
    }
  }

  Future<void> _editArea(Map<String, dynamic> area) async {
    final nameCtrl = TextEditingController(text: area['name']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _InputDialog(title: 'Modifica area', label: 'Nome area', controller: nameCtrl),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      await _supabase.from('areas').update({'name': nameCtrl.text.trim()}).eq('id', area['id']);
      _loadData();
    }
  }

  Future<void> _deleteArea(Map<String, dynamic> area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina area', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Eliminare "${area['name']}"? Anche i tavoli associati verranno eliminati.',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _supabase.from('areas').delete().eq('id', area['id']);
      _loadData();
    }
  }

  Future<void> _addTable(String areaId) async {
    final nameCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '2');
    final minCapCtrl = TextEditingController(text: '1');
    String shape = 'square';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Nuovo tavolo', style: TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _DialogField(label: 'Nome tavolo', controller: nameCtrl),
              const SizedBox(height: 8),
              _DialogField(label: 'Posti max', controller: capCtrl, numeric: true),
              const SizedBox(height: 8),
              _DialogField(label: 'Posti min', controller: minCapCtrl, numeric: true),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Forma:', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                ChoiceChip(label: const Text('Quadrato'), selected: shape == 'square',
                    onSelected: (_) => setS(() => shape = 'square')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Rotondo'), selected: shape == 'round',
                    onSelected: (_) => setS(() => shape = 'round')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Rettangolo'), selected: shape == 'rectangle',
                    onSelected: (_) => setS(() => shape = 'rectangle')),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Aggiungi'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      await _supabase.from('tables').insert({
        'restaurant_id': _restaurantId,
        'area_id': areaId,
        'name': nameCtrl.text.trim(),
        'capacity': int.tryParse(capCtrl.text) ?? 2,
        'min_capacity': int.tryParse(minCapCtrl.text) ?? 1,
        'shape': shape,
        'pos_x': 50.0,
        'pos_y': 50.0,
        'is_active': true,
      });
      _loadData();
    }
  }

  Future<void> _editTable(Map<String, dynamic> table) async {
    final nameCtrl = TextEditingController(text: table['name']);
    final capCtrl = TextEditingController(text: table['capacity'].toString());
    final minCapCtrl = TextEditingController(text: (table['min_capacity'] ?? 1).toString());
    String shape = table['shape'] ?? 'square';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Modifica tavolo', style: TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _DialogField(label: 'Nome tavolo', controller: nameCtrl),
              const SizedBox(height: 8),
              _DialogField(label: 'Posti max', controller: capCtrl, numeric: true),
              const SizedBox(height: 8),
              _DialogField(label: 'Posti min', controller: minCapCtrl, numeric: true),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('Quadrato'), selected: shape == 'square',
                    onSelected: (_) => setS(() => shape = 'square')),
                ChoiceChip(label: const Text('Rotondo'), selected: shape == 'round',
                    onSelected: (_) => setS(() => shape = 'round')),
                ChoiceChip(label: const Text('Rettangolo'), selected: shape == 'rectangle',
                    onSelected: (_) => setS(() => shape = 'rectangle')),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _supabase.from('tables').update({
        'name': nameCtrl.text.trim(),
        'capacity': int.tryParse(capCtrl.text) ?? 2,
        'min_capacity': int.tryParse(minCapCtrl.text) ?? 1,
        'shape': shape,
      }).eq('id', table['id']);
      _loadData();
    }
  }

  Future<void> _deleteTable(Map<String, dynamic> table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina tavolo', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Eliminare il tavolo "${table['name']}"?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _supabase.from('tables').delete().eq('id', table['id']);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.nero,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Tavoli', style: TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.bold)),
        actions: [
          ...azioniBarra(context),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'AREE E TAVOLI'),
            Tab(text: 'COMBINAZIONI'),
            Tab(text: 'PLANIMETRIA'),
          ],
        ),
      ),
      body: ContenutoCentrato(larghezzaMassima: 900,
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                // ── TAB AREE E TAVOLI ──
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'La funzione di gestione dei tavoli del nostro sistema ti consente di configurare le aree e i tavoli del tuo ristorante.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ..._areas.map((area) {
                      final tables = _tablesByArea[area['id']] ?? [];
                      return _AreaSection(
                        area: area,
                        tables: tables,
                        onEditArea: () => _editArea(area),
                        onDeleteArea: () => _deleteArea(area),
                        onAddTable: () => _addTable(area['id']),
                        onEditTable: (t) => _editTable(t),
                        onDeleteTable: (t) => _deleteTable(t),
                      );
                    }),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _addArea,
                      icon: const Icon(Icons.add, color: AppColors.textPrimary),
                      label: const Text('Aggiungi area', style: TextStyle(color: AppColors.textPrimary)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
                // ── TAB COMBINAZIONI ──
                const Center(child: Text('Combinazioni — in costruzione', style: TextStyle(color: AppColors.textSecondary))),
                // ── TAB PLANIMETRIA ──
                const Center(child: Text('Planimetria editor — in costruzione', style: TextStyle(color: AppColors.textSecondary))),
              ],
            )),
    );
  }
}

// ── Area Section ──────────────────────────────────────────────────────────────
class _AreaSection extends StatelessWidget {
  final Map<String, dynamic> area;
  final List<Map<String, dynamic>> tables;
  final VoidCallback onEditArea, onDeleteArea, onAddTable;
  final ValueChanged<Map<String, dynamic>> onEditTable, onDeleteTable;

  const _AreaSection({
    required this.area, required this.tables,
    required this.onEditArea, required this.onDeleteArea,
    required this.onAddTable, required this.onEditTable, required this.onDeleteTable,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(area['name'].toString().toUpperCase(),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20), onPressed: onEditArea),
          IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20), onPressed: onDeleteArea),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Text('Prenotabile  ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Text('Personale, Online', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              ...tables.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                return Column(children: [
                  _TableRow(
                    table: t,
                    onEdit: () => onEditTable(t),
                    onDelete: () => onDeleteTable(t),
                  ),
                  if (i < tables.length - 1)
                    const Divider(height: 1, color: AppColors.divider),
                ]);
              }),
              if (tables.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nessun tavolo in questa area',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAddTable,
            icon: const Icon(Icons.add, color: AppColors.textPrimary, size: 18),
            label: const Text('+ Aggiungi tavolo', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.divider),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  final Map<String, dynamic> table;
  final VoidCallback onEdit, onDelete;
  const _TableRow({required this.table, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cap = table['capacity'] ?? 2;
    final minCap = table['min_capacity'] ?? 1;
    final shape = table['shape'] ?? 'square';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(table['name'].toString(),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                const Text('Posti a sedere  ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Text('$minCap - $cap', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Text('Forma  ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Text(shape, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
              const SizedBox(height: 2),
              const Text('Prenotabile  Personale, Online',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
          Column(children: [
            IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20), onPressed: onDelete),
          ]),
        ],
      ),
    );
  }
}

// ── Dialog helpers ────────────────────────────────────────────────────────────
class _InputDialog extends StatelessWidget {
  final String title, label;
  final TextEditingController controller;
  const _InputDialog({required this.title, required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool numeric;
  const _DialogField({required this.label, required this.controller, this.numeric = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
      ),
    );
  }
}
