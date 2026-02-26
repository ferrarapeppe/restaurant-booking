import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/shared/widgets/app_drawer.dart';
import 'package:restaurant_booking/shared/theme/app_theme.dart';
import 'package:restaurant_booking/data/models/table_model.dart';
import 'package:restaurant_booking/core/providers/table_providers.dart';

class FloorplanScreen extends ConsumerWidget {
  const FloorplanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(areasProvider);
    final tablesAsync = ref.watch(tablesProvider);
    final selectedArea = ref.watch(selectedAreaProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Planimetria', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Tab aree
          areasAsync.when(
            loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: AppColors.accent))),
            error: (e, _) => const SizedBox(),
            data: (areas) => Container(
              color: AppColors.surface,
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: areas.map((area) {
                  final isSelected = (selectedArea ?? areas.first.id) == area.id;
                  return GestureDetector(
                    onTap: () => ref.read(selectedAreaProvider.notifier).state = area.id,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent : AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? AppColors.accent : AppColors.divider),
                      ),
                      child: Text(area.name,
                          style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Legenda
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _LegendDot(color: const Color(0xFF28A745), label: 'Libero'),
                const SizedBox(width: 16),
                _LegendDot(color: const Color(0xFF007BFF), label: 'Occupato'),
                const SizedBox(width: 16),
                _LegendDot(color: const Color(0xFFFFC107), label: 'Prenotato'),
                const SizedBox(width: 16),
                _LegendDot(color: const Color(0xFF6C757D), label: 'Inattivo'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Canvas planimetria
          Expanded(
            child: tablesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => Center(child: Text('Errore: $e')),
              data: (tables) => _FloorplanCanvas(tables: tables),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _FloorplanCanvas extends ConsumerStatefulWidget {
  final List<TableModel> tables;
  const _FloorplanCanvas({required this.tables});

  @override
  ConsumerState<_FloorplanCanvas> createState() => _FloorplanCanvasState();
}

class _FloorplanCanvasState extends ConsumerState<_FloorplanCanvas> {
  late List<TableModel> _tables;

  @override
  void initState() {
    super.initState();
    _tables = List.from(widget.tables);
  }

  @override
  void didUpdateWidget(_FloorplanCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tables != widget.tables) {
      _tables = List.from(widget.tables);
    }
  }

  String _getTableStatus(String tableId) {
    final statusMap = ref.read(tableStatusProvider);
    return statusMap[tableId] ?? 'free';
  }

  void _setTableStatus(String tableId, String status) {
    final statusMap = Map<String, String>.from(ref.read(tableStatusProvider));
    statusMap[tableId] = status;
    ref.read(tableStatusProvider.notifier).state = statusMap;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 2.0,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF8F9FA),
        child: Stack(
          children: [
            // Griglia di sfondo
            CustomPaint(
              size: const Size(double.infinity, double.infinity),
              painter: _GridPainter(),
            ),
            // Tavoli
            ..._tables.map((table) {
              final status = _getTableStatus(table.id);
              return Positioned(
                left: table.posX,
                top: table.posY,
                child: GestureDetector(
                  onTap: () => _showTableMenu(context, table, status),
                  onPanUpdate: (details) {
                    setState(() {
                      final idx = _tables.indexWhere((t) => t.id == table.id);
                      if (idx != -1) {
                        _tables[idx] = _tables[idx].copyWith(
                          posX: (_tables[idx].posX + details.delta.dx).clamp(0, 600),
                          posY: (_tables[idx].posY + details.delta.dy).clamp(0, 800),
                        );
                      }
                    });
                  },
                  onPanEnd: (_) async {
                    final idx = _tables.indexWhere((t) => t.id == table.id);
                    if (idx != -1) {
                      await ref.read(tableRepositoryProvider)
                          .updateTablePosition(table.id, _tables[idx].posX, _tables[idx].posY);
                    }
                  },
                  child: _TableWidget(table: table, status: status),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showTableMenu(BuildContext context, TableModel table, String currentStatus) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(table.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text('Capacità: ${table.minCapacity}-${table.capacity} persone',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(radius: 8, backgroundColor: Color(0xFF28A745)),
            title: const Text('Libero'),
            trailing: currentStatus == 'free' ? const Icon(Icons.check, color: AppColors.accent) : null,
            onTap: () { _setTableStatus(table.id, 'free'); Navigator.pop(context); },
          ),
          ListTile(
            leading: const CircleAvatar(radius: 8, backgroundColor: Color(0xFF007BFF)),
            title: const Text('Occupato'),
            trailing: currentStatus == 'occupied' ? const Icon(Icons.check, color: AppColors.accent) : null,
            onTap: () { _setTableStatus(table.id, 'occupied'); Navigator.pop(context); },
          ),
          ListTile(
            leading: const CircleAvatar(radius: 8, backgroundColor: Color(0xFFFFC107)),
            title: const Text('Prenotato'),
            trailing: currentStatus == 'reserved' ? const Icon(Icons.check, color: AppColors.accent) : null,
            onTap: () { _setTableStatus(table.id, 'reserved'); Navigator.pop(context); },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TableWidget extends StatelessWidget {
  final TableModel table;
  final String status;

  const _TableWidget({required this.table, required this.status});

  Color get _statusColor {
    switch (status) {
      case 'occupied': return const Color(0xFF007BFF);
      case 'reserved': return const Color(0xFFFFC107);
      default: return const Color(0xFF28A745);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRound = table.shape == 'round' || table.shape == 'circle';
    final isRect = table.shape == 'rectangle';
    final width = isRect ? 100.0 : 70.0;
    final height = isRect ? 60.0 : 70.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(isRound ? 50 : 12),
        border: Border.all(color: _statusColor, width: 2.5),
        boxShadow: [BoxShadow(color: _statusColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(table.name,
              style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 14)),
          Text('${table.capacity}p',
              style: TextStyle(color: _statusColor.withOpacity(0.8), fontSize: 11)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < 1000; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, 1000), paint);
    }
    for (double y = 0; y < 1000; y += step) {
      canvas.drawLine(Offset(0, y), Offset(1000, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
