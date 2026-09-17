class MoodBoardItem {
  final String id;
  final String weddingId;
  final String imagePath;
  final String category;
  final String caption;

  const MoodBoardItem({
    required this.id,
    required this.weddingId,
    required this.imagePath,
    this.category = 'Other',
    this.caption = '',
  });

  static const List<String> categories = [
    'Decor',
    'Attire',
    'Flowers',
    'Cake',
    'Venue',
    'Hair & Makeup',
    'Other',
  ];

  MoodBoardItem copyWith({String? imagePath, String? category, String? caption}) {
    return MoodBoardItem(
      id: id,
      weddingId: weddingId,
      imagePath: imagePath ?? this.imagePath,
      category: category ?? this.category,
      caption: caption ?? this.caption,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weddingId': weddingId,
      'imagePath': imagePath,
      'category': category,
      'caption': caption,
    };
  }

  factory MoodBoardItem.fromMap(Map<String, dynamic> map) {
    return MoodBoardItem(
      id: map['id'] as String,
      weddingId: map['weddingId'] as String,
      imagePath: map['imagePath'] as String,
      category: map['category'] as String? ?? 'Other',
      caption: map['caption'] as String? ?? '',
    );
  }
}
