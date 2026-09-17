class TimelineEvent {
  final String id;
  final String weddingId;
  final String title;
  final String category;
  final DateTime time;
  final String note;
  final String? lastEditedBy;
  final DateTime? lastEditedAt;

  const TimelineEvent({
    required this.id,
    required this.weddingId,
    required this.title,
    this.category = 'Other',
    required this.time,
    this.note = '',
    this.lastEditedBy,
    this.lastEditedAt,
  });

  static const List<String> categories = [
    'Preparation',
    'Ceremony',
    'Photography',
    'Reception',
    'Vendor',
    'Family & Guests',
    'Transportation',
    'Other',
  ];

  TimelineEvent copyWith({String? title, String? category, DateTime? time, String? note}) {
    return TimelineEvent(
      id: id,
      weddingId: weddingId,
      title: title ?? this.title,
      category: category ?? this.category,
      time: time ?? this.time,
      note: note ?? this.note,
      lastEditedBy: lastEditedBy,
      lastEditedAt: lastEditedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wedding_id': weddingId,
      'title': title,
      'category': category,
      'time': time.toIso8601String(),
      'note': note,
    };
  }

  factory TimelineEvent.fromMap(Map<String, dynamic> map) {
    return TimelineEvent(
      id: map['id'] as String,
      weddingId: map['wedding_id'] as String,
      title: map['title'] as String,
      category: map['category'] as String? ?? 'Other',
      time: DateTime.parse(map['time'] as String),
      note: map['note'] as String? ?? '',
      lastEditedBy: map['last_edited_by'] as String?,
      lastEditedAt: map['last_edited_at'] != null
          ? DateTime.parse(map['last_edited_at'] as String)
          : null,
    );
  }
}
