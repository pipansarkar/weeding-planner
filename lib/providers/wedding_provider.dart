import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/wedding.dart';

class WeddingProvider extends ChangeNotifier {
  static const _activeWeddingIdKey = 'active_wedding_id';

  final List<Wedding> _weddings = [];
  List<Wedding> get weddings => List.unmodifiable(_weddings);

  String? _activeWeddingId;
  String? get activeWeddingId => _activeWeddingId;

  Wedding? get activeWedding {
    if (_activeWeddingId == null) return null;
    try {
      return _weddings.firstWhere((w) => w.id == _activeWeddingId);
    } catch (_) {
      return _weddings.isNotEmpty ? _weddings.first : null;
    }
  }

  Future<void> load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('weddings', orderBy: 'createdAt ASC');
    _weddings
      ..clear()
      ..addAll(rows.map(Wedding.fromMap));

    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_activeWeddingIdKey);

    if (_weddings.isEmpty) {
      final wedding = Wedding(id: const Uuid().v4(), createdAt: DateTime.now());
      await db.insert('weddings', wedding.toMap());
      _weddings.add(wedding);
      _activeWeddingId = wedding.id;
      await prefs.setString(_activeWeddingIdKey, wedding.id);
    } else if (savedId != null && _weddings.any((w) => w.id == savedId)) {
      _activeWeddingId = savedId;
    } else {
      _activeWeddingId = _weddings.first.id;
      await prefs.setString(_activeWeddingIdKey, _activeWeddingId!);
    }
    notifyListeners();
  }

  Future<void> setActiveWedding(String id) async {
    if (!_weddings.any((w) => w.id == id)) return;
    _activeWeddingId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeWeddingIdKey, id);
    notifyListeners();
  }

  Future<Wedding> addWedding({
    String brideName = '',
    String groomName = '',
    DateTime? weddingDate,
    String currencyCode = 'INR',
  }) async {
    final wedding = Wedding(
      id: const Uuid().v4(),
      brideName: brideName,
      groomName: groomName,
      weddingDate: weddingDate,
      currencyCode: currencyCode,
      createdAt: DateTime.now(),
    );
    final db = await AppDatabase.instance.database;
    await db.insert('weddings', wedding.toMap());
    _weddings.add(wedding);
    notifyListeners();
    return wedding;
  }

  Future<void> updateWedding(Wedding wedding) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'weddings',
      wedding.toMap(),
      where: 'id = ?',
      whereArgs: [wedding.id],
    );
    final idx = _weddings.indexWhere((w) => w.id == wedding.id);
    if (idx != -1) _weddings[idx] = wedding;
    notifyListeners();
  }

  Future<void> deleteWedding(String id) async {
    if (_weddings.length <= 1) return;
    final db = await AppDatabase.instance.database;
    const tablesToScope = [
      'checklist_items',
      'budget_items',
      'guests',
      'vendors',
      'vendor_contact_logs',
      'timeline_events',
      'emergency_contacts',
      'seating_tables',
      'mood_board_items',
      'menu_items',
      'custom_lists',
    ];
    final customListIds = (await db.query(
      'custom_lists',
      columns: ['id'],
      where: 'weddingId = ?',
      whereArgs: [id],
    )).map((row) => row['id'] as String).toList();
    for (final listId in customListIds) {
      await db.delete('custom_list_items', where: 'listId = ?', whereArgs: [listId]);
    }
    for (final table in tablesToScope) {
      await db.delete(table, where: 'weddingId = ?', whereArgs: [id]);
    }
    await db.delete('weddings', where: 'id = ?', whereArgs: [id]);
    _weddings.removeWhere((w) => w.id == id);
    if (_activeWeddingId == id && _weddings.isNotEmpty) {
      await setActiveWedding(_weddings.first.id);
    }
    notifyListeners();
  }
}
