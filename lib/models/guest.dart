enum Gender { male, female }

enum RsvpStatus { pending, attending, declined }

class Guest {
  final String id;
  final String weddingId;
  final String name;
  final Gender gender;
  final String phone;
  final String address;
  final String note;
  final String category;
  final Set<String> events;
  final Map<String, RsvpStatus> rsvpByEvent;
  final int plusOnes;
  final String mealPreference;
  final bool invitationSent;
  final String giftReceived;
  final bool thankYouSent;
  final String? lastEditedBy;
  final DateTime? lastEditedAt;

  const Guest({
    required this.id,
    required this.weddingId,
    required this.name,
    this.gender = Gender.male,
    this.phone = '',
    this.address = '',
    this.note = '',
    required this.category,
    this.events = const {},
    this.rsvpByEvent = const {},
    this.plusOnes = 0,
    this.mealPreference = '',
    this.invitationSent = false,
    this.giftReceived = '',
    this.thankYouSent = false,
    this.lastEditedBy,
    this.lastEditedAt,
  });

  static const List<String> categories = [
    'Bride Family',
    'Groom Family',
    'Bride Friends',
    'Groom Friends',
    'Mutual Friends',
    'Bride Coworkers',
    'Groom Coworkers',
    'Vendors',
    'Other',
  ];

  static const List<String> eventTypes = [
    'Engagement',
    'Haldi',
    'Mehendi',
    'Sangeet',
    'Wedding',
    'Reception',
    'Bachelor Party',
    'Ashirbad',
  ];

  int get totalHeadcount => 1 + plusOnes;

  RsvpStatus rsvpFor(String event) => rsvpByEvent[event] ?? RsvpStatus.pending;

  Guest copyWith({
    String? name,
    Gender? gender,
    String? phone,
    String? address,
    String? note,
    String? category,
    Set<String>? events,
    Map<String, RsvpStatus>? rsvpByEvent,
    int? plusOnes,
    String? mealPreference,
    bool? invitationSent,
    String? giftReceived,
    bool? thankYouSent,
    String? lastEditedBy,
    DateTime? lastEditedAt,
  }) {
    return Guest(
      id: id,
      weddingId: weddingId,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      category: category ?? this.category,
      events: events ?? this.events,
      rsvpByEvent: rsvpByEvent ?? this.rsvpByEvent,
      plusOnes: plusOnes ?? this.plusOnes,
      mealPreference: mealPreference ?? this.mealPreference,
      invitationSent: invitationSent ?? this.invitationSent,
      giftReceived: giftReceived ?? this.giftReceived,
      thankYouSent: thankYouSent ?? this.thankYouSent,
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
    );
  }

  static Map<String, RsvpStatus> _decodeRsvp(Map<String, dynamic>? map) {
    if (map == null) return {};
    final result = <String, RsvpStatus>{};
    for (final entry in map.entries) {
      result[entry.key] = RsvpStatus.values.firstWhere(
        (e) => e.name == entry.value,
        orElse: () => RsvpStatus.pending,
      );
    }
    return result;
  }

  /// Row shape for insert/update against the Supabase `guests` table
  /// (snake_case columns; id/wedding_id/last_edited_* are server-managed
  /// on update but included on insert for client-generated ids).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'name': name,
      'gender': gender.name,
      'phone': phone,
      'address': address,
      'note': note,
      'category': category,
      'events': events.toList(),
      'rsvp_by_event': rsvpByEvent.map((k, v) => MapEntry(k, v.name)),
      'plus_ones': plusOnes,
      'meal_preference': mealPreference,
      'invitation_sent': invitationSent,
      'gift_received': giftReceived,
      'thank_you_sent': thankYouSent,
    };
  }

  factory Guest.fromMap(Map<String, dynamic> map) {
    final eventsList = (map['events'] as List<dynamic>?) ?? const [];
    return Guest(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      name: map['name'] as String,
      gender: Gender.values.firstWhere(
        (e) => e.name == map['gender'],
        orElse: () => Gender.male,
      ),
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      note: map['note'] as String? ?? '',
      category: map['category'] as String,
      events: eventsList.map((e) => e as String).toSet(),
      rsvpByEvent: _decodeRsvp(map['rsvp_by_event'] as Map<String, dynamic>?),
      plusOnes: (map['plus_ones'] as int?) ?? 0,
      mealPreference: map['meal_preference'] as String? ?? '',
      invitationSent: (map['invitation_sent'] as bool?) ?? false,
      giftReceived: map['gift_received'] as String? ?? '',
      thankYouSent: (map['thank_you_sent'] as bool?) ?? false,
      lastEditedBy: map['last_edited_by'] as String?,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.parse(map['last_edited_at'] as String)
          : null,
    );
  }
}
