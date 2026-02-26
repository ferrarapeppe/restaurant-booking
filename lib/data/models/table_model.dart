class AreaModel {
  final String id;
  final String restaurantId;
  final String name;
  final int sortOrder;

  const AreaModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.sortOrder,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      id: json['id'],
      restaurantId: json['restaurant_id'],
      name: json['name'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}

class TableModel {
  final String id;
  final String restaurantId;
  final String areaId;
  final String name;
  final int capacity;
  final int minCapacity;
  final double posX;
  final double posY;
  final String shape;
  final bool isActive;
  // Stato runtime (non nel DB)
  final String status; // free, occupied, reserved

  const TableModel({
    required this.id,
    required this.restaurantId,
    required this.areaId,
    required this.name,
    required this.capacity,
    required this.minCapacity,
    required this.posX,
    required this.posY,
    required this.shape,
    required this.isActive,
    this.status = 'free',
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'],
      restaurantId: json['restaurant_id'],
      areaId: json['area_id'],
      name: json['name'],
      capacity: json['capacity'] ?? 4,
      minCapacity: json['min_capacity'] ?? 1,
      posX: (json['pos_x'] ?? 50).toDouble(),
      posY: (json['pos_y'] ?? 50).toDouble(),
      shape: json['shape'] ?? 'square',
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'restaurant_id': restaurantId,
    'area_id': areaId,
    'name': name,
    'capacity': capacity,
    'min_capacity': minCapacity,
    'pos_x': posX,
    'pos_y': posY,
    'shape': shape,
    'is_active': isActive,
  };

  TableModel copyWith({double? posX, double? posY, String? status}) {
    return TableModel(
      id: id,
      restaurantId: restaurantId,
      areaId: areaId,
      name: name,
      capacity: capacity,
      minCapacity: minCapacity,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      shape: shape,
      isActive: isActive,
      status: status ?? this.status,
    );
  }
}
