import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/menu_item.dart';

class MenuProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;

  final List<MenuItem> _items = [];
  List<MenuItem> get items => List.unmodifiable(_items);

  Map<String, List<MenuItem>> get itemsByCourse {
    final map = <String, List<MenuItem>>{};
    for (final item in _items) {
      map.putIfAbsent(item.course, () => []).add(item);
    }
    return map;
  }

  Future<void> load({required String weddingId}) async {
    final rows = await _client
        .from('menu_items')
        .select()
        .eq('wedding_id', weddingId)
        .order('name');
    _items
      ..clear()
      ..addAll(rows.map(MenuItem.fromMap));
    notifyListeners();
    _subscribe(weddingId);
  }

  void _subscribe(String weddingId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('menu_items:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'menu_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: weddingId,
          ),
          callback: _handleRealtimeChange,
        )
        .subscribe();
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final item = MenuItem.fromMap(payload.newRecord);
        final idx = _items.indexWhere((e) => e.id == item.id);
        if (idx == -1) {
          _items.add(item);
        } else {
          _items[idx] = item;
        }
        break;
      case PostgresChangeEvent.delete:
        _items.removeWhere((e) => e.id == payload.oldRecord['id']);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> add({
    required String weddingId,
    required String name,
    required String course,
    Set<DietaryTag> dietaryTags = const {},
    String note = '',
  }) async {
    final item = MenuItem(
      id: const Uuid().v4(),
      weddingId: weddingId,
      name: name,
      course: course,
      dietaryTags: dietaryTags,
      note: note,
    );
    await _client.from('menu_items').insert(item.toMap());
  }

  Future<void> update(MenuItem item) async {
    await _client.from('menu_items').update(item.toMap()).eq('id', item.id);
  }

  Future<void> delete(String id) async {
    await _client.from('menu_items').delete().eq('id', id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
