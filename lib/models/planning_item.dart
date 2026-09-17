enum PlanningCategory {
  accommodation,
  transportation,
  jewelry,
  food,
  ceremonyVenue,
  decorationFlower;

  String get dbValue {
    switch (this) {
      case PlanningCategory.accommodation:
        return 'accommodation';
      case PlanningCategory.transportation:
        return 'transportation';
      case PlanningCategory.jewelry:
        return 'jewelry';
      case PlanningCategory.food:
        return 'food';
      case PlanningCategory.ceremonyVenue:
        return 'ceremony_venue';
      case PlanningCategory.decorationFlower:
        return 'decoration_flower';
    }
  }

  String get label {
    switch (this) {
      case PlanningCategory.accommodation:
        return 'Accommodation';
      case PlanningCategory.transportation:
        return 'Transportation';
      case PlanningCategory.jewelry:
        return 'Jewelry';
      case PlanningCategory.food:
        return 'Food';
      case PlanningCategory.ceremonyVenue:
        return 'Ceremony & Venue';
      case PlanningCategory.decorationFlower:
        return 'Decoration & Flower';
    }
  }

  /// Matching Budget category name, so a synced Budget entry lands in the
  /// budget category a user would already expect for this kind of expense.
  String get budgetCategory {
    switch (this) {
      case PlanningCategory.accommodation:
        return 'Accommodation';
      case PlanningCategory.transportation:
        return 'Transportation';
      case PlanningCategory.jewelry:
        return 'Jewelry';
      case PlanningCategory.food:
        return 'Food';
      case PlanningCategory.ceremonyVenue:
        return 'Ceremony & Venue';
      case PlanningCategory.decorationFlower:
        return 'Decoration & Flower';
    }
  }

  static PlanningCategory fromDbValue(String value) {
    return PlanningCategory.values.firstWhere(
      (c) => c.dbValue == value,
      orElse: () => PlanningCategory.accommodation,
    );
  }
}

enum PlanningStatus {
  planned,
  booked,
  purchased,
  done;

  String get label {
    switch (this) {
      case PlanningStatus.planned:
        return 'Planned';
      case PlanningStatus.booked:
        return 'Booked';
      case PlanningStatus.purchased:
        return 'Purchased';
      case PlanningStatus.done:
        return 'Done';
    }
  }
}

class PlanningItem {
  final String id;
  final String weddingId;
  final PlanningCategory category;
  final String title;
  final String? guestId;
  /// 'bride' or 'groom' when this item is for the couple themselves rather
  /// than a guest -- they're usually not entered as rows in Guests (that
  /// list is for who's invited), so [guestId] alone can't represent them.
  final String? forCouple;
  final String? vendorId;
  final String? budgetItemId;
  final double quantity;
  final double unitPrice;
  final PlanningStatus status;
  final String note;

  // Category-specific fields -- only the ones relevant to [category] are
  // meaningfully populated; the rest stay blank/null.
  final String eventName;
  final String venueName;
  final String address;
  final DateTime? eventDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String fromLocation;
  final String toLocation;
  final String vehicleType;
  final String occasion;
  final String course;
  final String placement;

  final String? lastEditedBy;
  final DateTime? lastEditedAt;

  const PlanningItem({
    required this.id,
    required this.weddingId,
    required this.category,
    required this.title,
    this.guestId,
    this.forCouple,
    this.vendorId,
    this.budgetItemId,
    this.quantity = 1,
    this.unitPrice = 0,
    this.status = PlanningStatus.planned,
    this.note = '',
    this.eventName = '',
    this.venueName = '',
    this.address = '',
    this.eventDate,
    this.startDate,
    this.endDate,
    this.fromLocation = '',
    this.toLocation = '',
    this.vehicleType = '',
    this.occasion = '',
    this.course = '',
    this.placement = '',
    this.lastEditedBy,
    this.lastEditedAt,
  });

  double get totalPrice => quantity * unitPrice;

  static const List<String> vehicleTypes = [
    'Car', 'Bus', 'Van', 'Limousine', 'Horse Carriage', 'Boat', 'Other',
  ];

  static const List<String> occasions = [
    'Engagement', 'Wedding', 'Reception', 'Other',
  ];

  static const List<String> courses = [
    'Starter', 'Main Course', 'Dessert', 'Beverage', 'Other',
  ];

  PlanningItem copyWith({
    String? title,
    String? guestId,
    bool clearGuestId = false,
    String? forCouple,
    bool clearForCouple = false,
    String? vendorId,
    bool clearVendorId = false,
    String? budgetItemId,
    bool clearBudgetItemId = false,
    double? quantity,
    double? unitPrice,
    PlanningStatus? status,
    String? note,
    String? eventName,
    String? venueName,
    String? address,
    DateTime? eventDate,
    DateTime? startDate,
    DateTime? endDate,
    String? fromLocation,
    String? toLocation,
    String? vehicleType,
    String? occasion,
    String? course,
    String? placement,
  }) {
    return PlanningItem(
      id: id,
      weddingId: weddingId,
      category: category,
      title: title ?? this.title,
      guestId: clearGuestId ? null : (guestId ?? this.guestId),
      forCouple: clearForCouple ? null : (forCouple ?? this.forCouple),
      vendorId: clearVendorId ? null : (vendorId ?? this.vendorId),
      budgetItemId: clearBudgetItemId ? null : (budgetItemId ?? this.budgetItemId),
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      status: status ?? this.status,
      note: note ?? this.note,
      eventName: eventName ?? this.eventName,
      venueName: venueName ?? this.venueName,
      address: address ?? this.address,
      eventDate: eventDate ?? this.eventDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      vehicleType: vehicleType ?? this.vehicleType,
      occasion: occasion ?? this.occasion,
      course: course ?? this.course,
      placement: placement ?? this.placement,
      lastEditedBy: lastEditedBy,
      lastEditedAt: lastEditedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'category': category.dbValue,
      'title': title,
      'guest_id': guestId,
      'for_couple': forCouple,
      'vendor_id': vendorId,
      'budget_item_id': budgetItemId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'status': status.name,
      'note': note,
      'event_name': eventName,
      'venue_name': venueName,
      'address': address,
      'event_date': eventDate?.toIso8601String().split('T').first,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'from_location': fromLocation,
      'to_location': toLocation,
      'vehicle_type': vehicleType,
      'occasion': occasion,
      'course': course,
      'placement': placement,
    };
  }

  factory PlanningItem.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String? key) =>
        map[key] != null ? DateTime.parse(map[key] as String) : null;
    return PlanningItem(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      category: PlanningCategory.fromDbValue(map['category'] as String),
      title: map['title'] as String,
      guestId: map['guest_id'] as String?,
      forCouple: map['for_couple'] as String?,
      vendorId: map['vendor_id'] as String?,
      budgetItemId: map['budget_item_id'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      status: PlanningStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PlanningStatus.planned,
      ),
      note: map['note'] as String? ?? '',
      eventName: map['event_name'] as String? ?? '',
      venueName: map['venue_name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      eventDate: parseDate('event_date'),
      startDate: parseDate('start_date'),
      endDate: parseDate('end_date'),
      fromLocation: map['from_location'] as String? ?? '',
      toLocation: map['to_location'] as String? ?? '',
      vehicleType: map['vehicle_type'] as String? ?? '',
      occasion: map['occasion'] as String? ?? '',
      course: map['course'] as String? ?? '',
      placement: map['placement'] as String? ?? '',
      lastEditedBy: map['last_edited_by'] as String?,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.parse(map['last_edited_at'] as String)
          : null,
    );
  }
}
