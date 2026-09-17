enum PaymentStatus { unpaid, partiallyPaid, paidInFull }

class BudgetItem {
  final String id;
  final String weddingId;
  final String name;
  final String category;
  final double estimatedAmount;
  final double actualAmount;
  final String note;
  final DateTime? dueDate;
  final String paymentMethod;
  final String paidBy;
  final PaymentStatus paymentStatus;
  final String? lastEditedBy;
  final DateTime? lastEditedAt;

  const BudgetItem({
    required this.id,
    required this.weddingId,
    required this.name,
    required this.category,
    this.estimatedAmount = 0,
    this.actualAmount = 0,
    this.note = '',
    this.dueDate,
    this.paymentMethod = '',
    this.paidBy = '',
    this.paymentStatus = PaymentStatus.unpaid,
    this.lastEditedBy,
    this.lastEditedAt,
  });

  static const List<String> categories = [
    'Attire & Accessories',
    'Beauty',
    'Music & Show',
    'Decoration & Flower',
    'Accessories',
    'Jewelry',
    'Photo & Video',
    'Ceremony & Venue',
    'Food',
    'Transportation',
    'Accommodation',
    'Other',
  ];

  BudgetItem copyWith({
    String? name,
    String? category,
    double? estimatedAmount,
    double? actualAmount,
    String? note,
    DateTime? dueDate,
    String? paymentMethod,
    String? paidBy,
    PaymentStatus? paymentStatus,
  }) {
    return BudgetItem(
      id: id,
      weddingId: weddingId,
      name: name ?? this.name,
      category: category ?? this.category,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      actualAmount: actualAmount ?? this.actualAmount,
      note: note ?? this.note,
      dueDate: dueDate ?? this.dueDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidBy: paidBy ?? this.paidBy,
      paymentStatus: paymentStatus ?? this.paymentStatus,
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
      'estimated_amount': estimatedAmount,
      'actual_amount': actualAmount,
      'note': note,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'payment_method': paymentMethod,
      'paid_by': paidBy,
      'payment_status': paymentStatus.name,
    };
  }

  factory BudgetItem.fromMap(Map<String, dynamic> map) {
    return BudgetItem(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      estimatedAmount: (map['estimated_amount'] as num?)?.toDouble() ?? 0,
      actualAmount: (map['actual_amount'] as num?)?.toDouble() ?? 0,
      note: map['note'] as String? ?? '',
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
      paymentMethod: map['payment_method'] as String? ?? '',
      paidBy: map['paid_by'] as String? ?? '',
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == map['payment_status'],
        orElse: () => PaymentStatus.unpaid,
      ),
      lastEditedBy: map['last_edited_by'] as String?,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.parse(map['last_edited_at'] as String)
          : null,
    );
  }
}
