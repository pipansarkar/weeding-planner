class CustomListItem {
  final String id;
  final String listId;
  final Map<String, dynamic> values;

  const CustomListItem({
    required this.id,
    required this.listId,
    this.values = const {},
  });

  CustomListItem copyWith({Map<String, dynamic>? values}) {
    return CustomListItem(
      id: id,
      listId: listId,
      values: values ?? this.values,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'list_id': listId,
      'field_values': values,
    };
  }

  factory CustomListItem.fromMap(Map<String, dynamic> map) {
    return CustomListItem(
      id: map['id'] as String,
      listId: map['list_id'] as String,
      values: (map['field_values'] as Map<String, dynamic>?) ?? const {},
    );
  }
}
