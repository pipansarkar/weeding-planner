enum DietaryTag { veg, nonVeg, vegan, glutenFree, jain }

class MenuItem {
  final String id;
  final String weddingId;
  final String name;
  final String course;
  final Set<DietaryTag> dietaryTags;
  final String note;
  final String? lastEditedBy;
  final DateTime? lastEditedAt;

  const MenuItem({
    required this.id,
    required this.weddingId,
    required this.name,
    required this.course,
    this.dietaryTags = const {},
    this.note = '',
    this.lastEditedBy,
    this.lastEditedAt,
  });

  static const List<String> courses = [
    'Starters',
    'Mains',
    'Breads & Rice',
    'Dessert',
    'Drinks & Beverages',
    'Other',
  ];

  MenuItem copyWith({
    String? name,
    String? course,
    Set<DietaryTag>? dietaryTags,
    String? note,
  }) {
    return MenuItem(
      id: id,
      weddingId: weddingId,
      name: name ?? this.name,
      course: course ?? this.course,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      note: note ?? this.note,
      lastEditedBy: lastEditedBy,
      lastEditedAt: lastEditedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'name': name,
      'course': course,
      'dietary_tags': dietaryTags.map((t) => t.name).toList(),
      'note': note,
    };
  }

  factory MenuItem.fromMap(Map<String, dynamic> map) {
    final tagsList = (map['dietary_tags'] as List<dynamic>?) ?? const [];
    return MenuItem(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      name: map['name'] as String,
      course: map['course'] as String,
      dietaryTags: tagsList
          .map((t) => DietaryTag.values.firstWhere(
                (e) => e.name == t,
                orElse: () => DietaryTag.veg,
              ))
          .toSet(),
      note: map['note'] as String? ?? '',
      lastEditedBy: map['last_edited_by'] as String?,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.parse(map['last_edited_at'] as String)
          : null,
    );
  }
}
