import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/mood_board_item.dart';

class MoodBoardProvider extends ChangeNotifier {
  final List<MoodBoardItem> _items = [];
  List<MoodBoardItem> get items => List.unmodifiable(_items);

  Future<void> load({required String weddingId}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'mood_board_items',
      where: 'weddingId = ?',
      whereArgs: [weddingId],
    );
    _items
      ..clear()
      ..addAll(rows.map(MoodBoardItem.fromMap));
    notifyListeners();
  }

  Future<void> add({
    required String weddingId,
    required String imagePath,
    String category = 'Other',
    String caption = '',
  }) async {
    final item = MoodBoardItem(
      id: const Uuid().v4(),
      weddingId: weddingId,
      imagePath: imagePath,
      category: category,
      caption: caption,
    );
    final db = await AppDatabase.instance.database;
    await db.insert('mood_board_items', item.toMap());
    _items.add(item);
    notifyListeners();
  }

  Future<void> update(MoodBoardItem item) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'mood_board_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx != -1) _items[idx] = item;
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('mood_board_items', where: 'id = ?', whereArgs: [id]);
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}
