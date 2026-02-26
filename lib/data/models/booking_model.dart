class GuestModel {
  final String id;
  final String restaurantId;
  final String name;
  final String? email;
  final String? phone;
  final String? notes;
  final List<String> tags;
  final int visitsCount;

  const GuestModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.email,
    this.phone,
    this.notes,
    this.tags = const [],
    this.visitsCount = 0,
  });

  factory GuestModel.fromJson(Map<String, dynamic> json) {
    return GuestModel(
      id: json['id'],
      restaurantId: json['restaurant_id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      notes: json['notes'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      visitsCount: json['visits_count'] ?? 0,
    );
  }
}

class BookingModel {
  final String id;
  final String restaurantId;
  final String? guestId;
  final String? tableId;
  final DateTime date;
  final String timeStart;
  final String? timeEnd;
  final int partySize;
  final String status;
  final String? notes;
  final String? internalNotes;
  final String source;
  final DateTime? createdAt;
  // Join da guests
  final GuestModel? guest;

  const BookingModel({
    required this.id,
    required this.restaurantId,
    this.guestId,
    this.tableId,
    required this.date,
    required this.timeStart,
    this.timeEnd,
    required this.partySize,
    required this.status,
    this.notes,
    this.internalNotes,
    this.source = 'web',
    this.createdAt,
    this.guest,
  });

  // Nome da mostrare in UI
  String get guestName => guest?.name ?? 'Ospite';
  String get guestPhone => guest?.phone ?? '';
  String get guestEmail => guest?.email ?? '';

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'],
      restaurantId: json['restaurant_id'],
      guestId: json['guest_id'],
      tableId: json['table_id'],
      date: DateTime.parse(json['date'] + 'T00:00:00'),
      timeStart: json['time_start'] ?? '00:00',
      timeEnd: json['time_end'],
      partySize: json['party_size'],
      status: json['status'] ?? 'confirmed',
      notes: json['notes'],
      internalNotes: json['internal_notes'],
      source: json['source'] ?? 'web',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      guest: json['guests'] != null ? GuestModel.fromJson(json['guests']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurant_id': restaurantId,
      'guest_id': guestId,
      'table_id': tableId,
      'date': date.toIso8601String().split('T')[0],
      'time_start': timeStart,
      'time_end': timeEnd,
      'party_size': partySize,
      'status': status,
      'notes': notes,
      'internal_notes': internalNotes,
      'source': source,
    };
  }

  BookingModel copyWith({String? status, String? tableId, String? notes, String? internalNotes}) {
    return BookingModel(
      id: id,
      restaurantId: restaurantId,
      guestId: guestId,
      tableId: tableId ?? this.tableId,
      date: date,
      timeStart: timeStart,
      timeEnd: timeEnd,
      partySize: partySize,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      internalNotes: internalNotes ?? this.internalNotes,
      source: source,
      createdAt: createdAt,
      guest: guest,
    );
  }
}
