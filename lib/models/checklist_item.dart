enum ChecklistStatus { pending, completed }

class ChecklistItem {
  final String id;
  final String weddingId;
  final String name;
  final String category;
  final DateTime? date;
  final String note;
  final ChecklistStatus status;
  final String? lastEditedBy;
  final DateTime? lastEditedAt;

  const ChecklistItem({
    required this.id,
    required this.weddingId,
    required this.name,
    required this.category,
    this.date,
    this.note = '',
    this.status = ChecklistStatus.pending,
    this.lastEditedBy,
    this.lastEditedAt,
  });

  static const List<String> categories = [
    'Attire & Accessories',
    'Beauty',
    'Music & Show',
    'Decoration & Flower',
    'Jewelry',
    'Photo & Video',
    'Ceremony & Venue',
    'Food',
    'Transportation',
    'Accommodation',
    'Invitations',
    'Other',
  ];

  ChecklistItem copyWith({
    String? name,
    String? category,
    DateTime? date,
    String? note,
    ChecklistStatus? status,
  }) {
    return ChecklistItem(
      id: id,
      weddingId: weddingId,
      name: name ?? this.name,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      status: status ?? this.status,
      lastEditedBy: lastEditedBy,
      lastEditedAt: lastEditedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'name': name,
      'category': category,
      'date': date?.toIso8601String().split('T').first,
      'note': note,
      'status': status.name,
    };
  }

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
      note: map['note'] as String? ?? '',
      status: ChecklistStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ChecklistStatus.pending,
      ),
      lastEditedBy: map['last_edited_by'] as String?,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.parse(map['last_edited_at'] as String)
          : null,
    );
  }
}
