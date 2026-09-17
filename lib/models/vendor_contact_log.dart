class VendorContactLog {
  final String id;
  final String weddingId;
  final String vendorId;
  final DateTime date;
  final String note;

  const VendorContactLog({
    required this.id,
    required this.weddingId,
    required this.vendorId,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'vendor_id': vendorId,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory VendorContactLog.fromMap(Map<String, dynamic> map) {
    return VendorContactLog(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      vendorId: map['vendor_id'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String? ?? '',
    );
  }
}
