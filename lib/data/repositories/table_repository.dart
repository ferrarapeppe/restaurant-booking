import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurant_booking/data/models/table_model.dart';

class TableRepository {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _restaurantId = '2b126a92-24d5-4e83-b38c-dfc82035a0cf';

  Future<List<AreaModel>> getAreas() async {
    final response = await _client
        .from('areas')
        .select()
        .eq('restaurant_id', _restaurantId)
        .order('sort_order', ascending: true);
    return (response as List).map((e) => AreaModel.fromJson(e)).toList();
  }

  Future<List<TableModel>> getTablesByArea(String areaId) async {
    final response = await _client
        .from('tables')
        .select()
        .eq('restaurant_id', _restaurantId)
        .eq('area_id', areaId)
        .eq('is_active', true);
    return (response as List).map((e) => TableModel.fromJson(e)).toList();
  }

  Future<void> updateTablePosition(String id, double posX, double posY) async {
    await _client.from('tables').update({'pos_x': posX, 'pos_y': posY}).eq('id', id);
  }

  Future<AreaModel> createArea(String name, int sortOrder) async {
    final response = await _client
        .from('areas')
        .insert({'restaurant_id': _restaurantId, 'name': name, 'sort_order': sortOrder})
        .select()
        .single();
    return AreaModel.fromJson(response);
  }

  Future<void> updateArea(String id, String name) async {
    await _client.from('areas').update({'name': name}).eq('id', id);
  }

  Future<void> deleteArea(String id) async {
    await _client.from('areas').delete().eq('id', id);
  }

  Future<TableModel> createTable(TableModel table) async {
    final response = await _client
        .from('tables')
        .insert(table.toJson())
        .select()
        .single();
    return TableModel.fromJson(response);
  }

  Future<void> updateTable(String id, {String? name, int? capacity, int? minCapacity, String? shape}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (capacity != null) data['capacity'] = capacity;
    if (minCapacity != null) data['min_capacity'] = minCapacity;
    if (shape != null) data['shape'] = shape;
    if (data.isNotEmpty) await _client.from('tables').update(data).eq('id', id);
  }

  Future<void> deleteTable(String id) async {
    await _client.from('tables').delete().eq('id', id);
  }
}
