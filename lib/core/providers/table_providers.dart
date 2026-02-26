import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurant_booking/data/models/table_model.dart';
import 'package:restaurant_booking/data/repositories/table_repository.dart';

final tableRepositoryProvider = Provider<TableRepository>((ref) => TableRepository());

final areasProvider = FutureProvider<List<AreaModel>>((ref) async {
  return ref.watch(tableRepositoryProvider).getAreas();
});

final selectedAreaProvider = StateProvider<String?>((ref) => null);

final tablesProvider = FutureProvider.autoDispose<List<TableModel>>((ref) async {
  final areas = await ref.watch(areasProvider.future);
  if (areas.isEmpty) return [];
  final selectedArea = ref.watch(selectedAreaProvider);
  final areaId = selectedArea ?? areas.first.id;
  return ref.watch(tableRepositoryProvider).getTablesByArea(areaId);
});

// Stato runtime tavoli (free/occupied/reserved)
final tableStatusProvider = StateProvider<Map<String, String>>((ref) => {});
