enum CustomFieldType { text, number, date, checkbox, dropdown }

class CustomFieldDef {
  final String id;
  final String label;
  final CustomFieldType type;
  final List<String> options;

  const CustomFieldDef({
    required this.id,
    required this.label,
    required this.type,
    this.options = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'type': type.name,
        'options': options,
      };

  factory CustomFieldDef.fromJson(Map<String, dynamic> json) {
    return CustomFieldDef(
      id: json['id'] as String,
      label: json['label'] as String,
      type: CustomFieldType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CustomFieldType.text,
      ),
      options: (json['options'] as List<dynamic>? ?? []).cast<String>(),
    );
  }
}

class CustomList {
  final String id;
  final String weddingId;
  final String name;
  final String icon;
  final List<CustomFieldDef> fields;
  final String? lastEditedBy;
  final DateTime? lastEditedAt;

  const CustomList({
    required this.id,
    required this.weddingId,
    required this.name,
    this.icon = 'list_alt',
    this.fields = const [],
    this.lastEditedBy,
    this.lastEditedAt,
  });

  CustomList copyWith({String? name, String? icon, List<CustomFieldDef>? fields}) {
    return CustomList(
      id: id,
      weddingId: weddingId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      fields: fields ?? this.fields,
      lastEditedBy: lastEditedBy,
      lastEditedAt: lastEditedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'name': name,
      'icon': icon,
      'fields': fields.map((f) => f.toJson()).toList(),
    };
  }

  factory CustomList.fromMap(Map<String, dynamic> map) {
    final fieldsRaw = (map['fields'] as List<dynamic>?) ?? const [];
    final decoded = fieldsRaw
        .map((f) => CustomFieldDef.fromJson(f as Map<String, dynamic>))
        .toList();
    return CustomList(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String? ?? 'list_alt',
      fields: decoded,
      lastEditedBy: map['last_edited_by'] as String?,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.parse(map['last_edited_at'] as String)
          : null,
    );
  }
}
