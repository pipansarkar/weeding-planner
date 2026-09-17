class SeatingTable {
  final String id;
  final String weddingId;
  final String name;
  final int capacity;
  final List<String> guestIds;
  final String? lastEditedBy;
  final DateTime? lastEditedAt;

  const SeatingTable({
    required this.id,
    required this.weddingId,
    required this.name,
    this.capacity = 8,
    this.guestIds = const [],
    this.lastEditedBy,
    this.lastEditedAt,
  });

  SeatingTable copyWith({String? name, int? capacity, List<String>? guestIds}) {
    return SeatingTable(
      id: id,
      weddingId: weddingId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      guestIds: guestIds ?? this.guestIds,
      lastEditedBy: lastEditedBy,
      lastEditedAt: lastEditedAt,
    );
  }

  /// Row shape for the seating_tables table itself. guestIds is NOT a column
  /// here -- assignments live in the separate seating_assignments join table
  /// (see SeatingProvider), so this map never includes guestIds.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'name': name,
      'capacity': capacity,
    };
  }

  /// Builds from a seating_tables row; guestIds must be supplied separately
  /// by the provider (joined from seating_assignments), defaulting to empty.
  factory SeatingTable.fromMap(Map<String, dynamic> map, {List<String> guestIds = const []}) {
    return SeatingTable(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      name: map['name'] as String,
      capacity: (map['capacity'] as int?) ?? 8,
      guestIds: guestIds,
      lastEditedBy: map['last_edited_by'] as String?,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.parse(map['last_edited_at'] as String)
          : null,
    );
  }
}
