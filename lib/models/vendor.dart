enum VendorStatus { reserved, pending, rejected }

class Vendor {
  final String id;
  final String weddingId;
  final String name;
  final String category;
  final String phone;
  final String site;
  final String address;
  final double amount;
  final VendorStatus status;
  final String note;
  final String? lastEditedBy;
  final DateTime? lastEditedAt;

  const Vendor({
    required this.id,
    required this.weddingId,
    required this.name,
    required this.category,
    this.phone = '',
    this.site = '',
    this.address = '',
    this.amount = 0,
    this.status = VendorStatus.pending,
    this.note = '',
    this.lastEditedBy,
    this.lastEditedAt,
  });

  static const List<String> categories = [
    'Attire & Accessories',
    'Beauty',
    'Music & Show',
    'Flower & Decoration',
    'Accessories',
    'Jewelry',
    'Photo & Video',
    'Ceremony',
    'Reception',
    'Transportation',
    'Accommodation',
    'Other',
  ];

  Vendor copyWith({
    String? name,
    String? category,
    String? phone,
    String? site,
    String? address,
    double? amount,
    VendorStatus? status,
    String? note,
  }) {
    return Vendor(
      id: id,
      weddingId: weddingId,
      name: name ?? this.name,
      category: category ?? this.category,
      phone: phone ?? this.phone,
      site: site ?? this.site,
      address: address ?? this.address,
      amount: amount ?? this.amount,
      status: status ?? this.status,
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
      'category': category,
      'phone': phone,
      'site': site,
      'address': address,
      'amount': amount,
      'status': status.name,
      'note': note,
    };
  }

  factory Vendor.fromMap(Map<String, dynamic> map) {
    return Vendor(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      phone: map['phone'] as String? ?? '',
      site: map['site'] as String? ?? '',
      address: map['address'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: VendorStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => VendorStatus.pending,
      ),
      note: map['note'] as String? ?? '',
      lastEditedBy: map['last_edited_by'] as String?,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.parse(map['last_edited_at'] as String)
          : null,
    );
  }
}
