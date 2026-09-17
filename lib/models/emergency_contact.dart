class EmergencyContact {
  final String id;
  final String weddingId;
  final String name;
  final String role;
  final String phone;
  final String? lastEditedBy;
  final DateTime? lastEditedAt;

  const EmergencyContact({
    required this.id,
    required this.weddingId,
    required this.name,
    this.role = '',
    this.phone = '',
    this.lastEditedBy,
    this.lastEditedAt,
  });

  EmergencyContact copyWith({String? name, String? role, String? phone}) {
    return EmergencyContact(
      id: id,
      weddingId: weddingId,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      lastEditedBy: lastEditedBy,
      lastEditedAt: lastEditedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'name': name,
      'role': role,
      'phone': phone,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      name: map['name'] as String,
      role: map['role'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      lastEditedBy: map['last_edited_by'] as String?,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.parse(map['last_edited_at'] as String)
          : null,
    );
  }
}
