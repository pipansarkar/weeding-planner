class Wedding {
  final String id;
  final String brideName;
  final String groomName;
  final DateTime? weddingDate;
  final String currencyCode;
  final DateTime createdAt;

  const Wedding({
    required this.id,
    this.brideName = '',
    this.groomName = '',
    this.weddingDate,
    this.currencyCode = 'INR',
    required this.createdAt,
  });

  String get displayName {
    if (brideName.isEmpty && groomName.isEmpty) return 'Untitled Wedding';
    if (brideName.isEmpty) return groomName;
    if (groomName.isEmpty) return brideName;
    return '$brideName & $groomName';
  }

  Wedding copyWith({
    String? brideName,
    String? groomName,
    DateTime? weddingDate,
    String? currencyCode,
  }) {
    return Wedding(
      id: id,
      brideName: brideName ?? this.brideName,
      groomName: groomName ?? this.groomName,
      weddingDate: weddingDate ?? this.weddingDate,
      currencyCode: currencyCode ?? this.currencyCode,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brideName': brideName,
      'groomName': groomName,
      'weddingDate': weddingDate?.toIso8601String(),
      'currencyCode': currencyCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Wedding.fromMap(Map<String, dynamic> map) {
    return Wedding(
      id: map['id'] as String,
      brideName: map['brideName'] as String? ?? '',
      groomName: map['groomName'] as String? ?? '',
      weddingDate: map['weddingDate'] != null
          ? DateTime.parse(map['weddingDate'] as String)
          : null,
      currencyCode: map['currencyCode'] as String? ?? 'INR',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
