import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/data/models/table_model.dart';
import 'package:restaurant_booking/core/providers/table_providers.dart';

class ManageAreasScreen extends ConsumerWidget {
  const ManageAreasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(areasProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Gestione Sale', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.accent), onPressed: () => _showAddAreaDialog(context, ref)),
        ],
      ),
      body: areasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (areas) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: areas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final area = areas[index];
            return Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
              child: ListTile(
                leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.table_restaurant, color: AppColors.accent, size: 22)),
                title: Text(area.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                subtitle: const Text('Tocca per gestire i tavoli', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20), onPressed: () => _showEditAreaDialog(context, ref, area)),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _showDeleteDialog(context, ref, area)),
                ]),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageTablesScreen(area: area))),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddAreaDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuova sala'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Nome sala')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final areas = await ref.read(areasProvider.future);
                await ref.read(tableRepositoryProvider).createArea(controller.text, areas.length);
                ref.invalidate(areasProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Crea', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showEditAreaDialog(BuildContext context, WidgetRef ref, AreaModel area) {
    final controller = TextEditingController(text: area.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rinomina sala'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Nome sala')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ref.read(tableRepositoryProvider).updateArea(area.id, controller.text);
                ref.invalidate(areasProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Salva', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, AreaModel area) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina sala'),
        content: Text('Eliminare "${area.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              await ref.read(tableRepositoryProvider).deleteArea(area.id);
              ref.invalidate(areasProvider);
              ref.invalidate(tablesProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ManageTablesScreen extends ConsumerStatefulWidget {
  final AreaModel area;
  const ManageTablesScreen({super.key, required this.area});

  @override
  ConsumerState<ManageTablesScreen> createState() => _ManageTablesScreenState();
}

class _ManageTablesScreenState extends ConsumerState<ManageTablesScreen> {
  List<TableModel> _tables = [];
  bool _loading = true;
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _loading = true);
    final tables = await ref.read(tableRepositoryProvider).getTablesByArea(widget.area.id);
    setState(() { _tables = tables; _loading = false; });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  int _nextTableNumber() {
    final nums = _tables.map((t) {
      final match = RegExp(r'\d+').firstMatch(t.name);
      return match != null ? int.tryParse(match.group(0)!) ?? 0 : 0;
    }).toList()..sort();
    return (nums.isEmpty ? 0 : nums.last) + 1;
  }

  Future<void> _duplicateSingle(TableModel table) async {
    final nextNum = _nextTableNumber();
    final newTable = TableModel(
      id: '', restaurantId: table.restaurantId, areaId: table.areaId,
      name: 'T$nextNum', capacity: table.capacity, minCapacity: table.minCapacity,
      posX: table.posX + 20, posY: table.posY + 20, shape: table.shape, isActive: true,
    );
    await ref.read(tableRepositoryProvider).createTable(newTable);
    ref.invalidate(tablesProvider);
    await _loadTables();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicato come T$nextNum!'), backgroundColor: AppColors.accent),
      );
    }
  }

  Future<void> _duplicateSelected() async {
    final selected = _tables.where((t) => _selectedIds.contains(t.id)).toList();
    int nextNum = _nextTableNumber();
    for (final table in selected) {
      final newTable = TableModel(
        id: '', restaurantId: table.restaurantId, areaId: table.areaId,
        name: 'T$nextNum', capacity: table.capacity, minCapacity: table.minCapacity,
        posX: table.posX + 20, posY: table.posY + 20, shape: table.shape, isActive: true,
      );
      await ref.read(tableRepositoryProvider).createTable(newTable);
      nextNum++;
    }
    ref.invalidate(tablesProvider);
    setState(() { _selectedIds.clear(); _selectionMode = false; });
    await _loadTables();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.length} tavoli duplicati!'), backgroundColor: AppColors.accent),
      );
    }
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina tavoli'),
        content: Text('Eliminare ${_selectedIds.length} tavoli?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      for (final id in _selectedIds) {
        await ref.read(tableRepositoryProvider).deleteTable(id);
      }
      ref.invalidate(tablesProvider);
      setState(() { _selectedIds.clear(); _selectionMode = false; });
      await _loadTables();
    }
  }

  Future<void> _deleteTable(TableModel table) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina tavolo'),
        content: Text('Eliminare "${table.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(tableRepositoryProvider).deleteTable(table.id);
      ref.invalidate(tablesProvider);
      await _loadTables();
    }
  }

  void _showAddTableDialog() {
    final nextNum = _nextTableNumber();
    final nameCtrl = TextEditingController(text: 'T$nextNum');
    int capacity = 4;
    int minCapacity = 2;
    String shape = 'square';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuovo tavolo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome tavolo')),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Max ospiti', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Row(children: [
                      IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: () => setState(() { if (capacity > 1) capacity--; })),
                      Text('$capacity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => setState(() => capacity++)),
                    ]),
                  ])),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Min ospiti', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Row(children: [
                      IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: () => setState(() { if (minCapacity > 1) minCapacity--; })),
                      Text('$minCapacity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => setState(() => minCapacity++)),
                    ]),
                  ])),
                ]),
                const SizedBox(height: 8),
                const Text('Forma', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(children: [
                  for (final s in [('square', 'Quadrato'), ('rectangle', 'Rettangolo'), ('round', 'Tondo')])
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => shape = s.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: shape == s.$1 ? AppColors.accentLight : AppColors.background,
                          border: Border.all(color: shape == s.$1 ? AppColors.accent : AppColors.divider),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(s.$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: shape == s.$1 ? AppColors.accent : AppColors.textSecondary)),
                      ),
                    )),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final newTable = TableModel(
                    id: '', restaurantId: '2b126a92-24d5-4e83-b38c-dfc82035a0cf',
                    areaId: widget.area.id, name: nameCtrl.text,
                    capacity: capacity, minCapacity: minCapacity,
                    posX: 50, posY: 50, shape: shape, isActive: true,
                  );
                  await ref.read(tableRepositoryProvider).createTable(newTable);
                  ref.invalidate(tablesProvider);
                  if (context.mounted) Navigator.pop(context);
                  await _loadTables();
                }
              },
              child: const Text('Crea', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTableDialog(TableModel table) {
    final nameCtrl = TextEditingController(text: table.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica tavolo'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome tavolo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              await ref.read(tableRepositoryProvider).updateTable(table.id, name: nameCtrl.text);
              ref.invalidate(tablesProvider);
              if (context.mounted) Navigator.pop(context);
              await _loadTables();
            },
            child: const Text('Salva', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: Icon(_selectionMode ? Icons.close : Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (_selectionMode) {
              setState(() { _selectedIds.clear(); _selectionMode = false; });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _selectionMode ? '${_selectedIds.length} selezionati' : widget.area.name,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: _selectionMode ? [
          IconButton(icon: const Icon(Icons.select_all, color: AppColors.textSecondary), tooltip: 'Seleziona tutti',
              onPressed: () => setState(() => _selectedIds.addAll(_tables.map((t) => t.id)))),
          IconButton(icon: const Icon(Icons.copy_outlined, color: AppColors.accent), tooltip: 'Duplica selezionati',
              onPressed: _selectedIds.isEmpty ? null : _duplicateSelected),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Elimina selezionati',
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected),
        ] : [
          IconButton(icon: const Icon(Icons.checklist, color: AppColors.textSecondary), tooltip: 'Selezione multipla',
              onPressed: () => setState(() => _selectionMode = true)),
          IconButton(icon: const Icon(Icons.add, color: AppColors.accent), onPressed: _showAddTableDialog),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _tables.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.table_restaurant_outlined, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('Nessun tavolo', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddTableDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi tavolo'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                  ),
                ]))
              : Column(children: [
                  if (_selectionMode)
                    Container(
                      color: AppColors.accentLight,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: AppColors.accent, size: 16),
                        const SizedBox(width: 8),
                        const Text('Tocca per selezionare, tieni premuto per iniziare', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _selectedIds.addAll(_tables.map((t) => t.id))),
                          child: const Text('Tutti', style: TextStyle(color: AppColors.accent)),
                        ),
                      ]),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tables.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final table = _tables[index];
                        final isSelected = _selectedIds.contains(table.id);
                        return GestureDetector(
                          onTap: () {
                            if (_selectionMode) _toggleSelection(table.id);
                          },
                          onLongPress: () {
                            setState(() => _selectionMode = true);
                            _toggleSelection(table.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accentLight : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? AppColors.accent : AppColors.divider, width: isSelected ? 2 : 1),
                            ),
                            child: Row(children: [
                              if (_selectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined,
                                      color: isSelected ? AppColors.accent : AppColors.textMuted, size: 24),
                                ),
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.accentLight,
                                  borderRadius: BorderRadius.circular(table.shape == 'round' ? 22 : 8),
                                ),
                                child: Center(child: Text(table.name, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(table.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                Text('${table.minCapacity}-${table.capacity} persone · ${table.shape}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ])),
                              if (!_selectionMode) ...[
                                IconButton(icon: const Icon(Icons.copy_outlined, color: AppColors.textSecondary, size: 20), tooltip: 'Duplica', onPressed: () => _duplicateSingle(table)),
                                IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20), onPressed: () => _showEditTableDialog(table)),
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteTable(table)),
                              ],
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}
