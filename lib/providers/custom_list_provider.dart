import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/custom_list.dart';
import '../models/custom_list_item.dart';

class CustomListProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  RealtimeChannel? _listsChannel;
  RealtimeChannel? _itemsChannel;

  final List<CustomList> _lists = [];
  List<CustomList> get lists => List.unmodifiable(_lists);

  final Map<String, List<CustomListItem>> _itemsByList = {};
  List<CustomListItem> itemsFor(String listId) =>
      List.unmodifiable(_itemsByList[listId] ?? const []);

  Future<void> load({required String weddingId}) async {
    final listRows = await _client
        .from('custom_lists')
        .select()
        .eq('wedding_id', weddingId)
        .order('name');
    _lists
      ..clear()
      ..addAll(listRows.map(CustomList.fromMap));

    _itemsByList.clear();
    for (final list in _lists) {
      final itemRows = await _client.from('custom_list_items').select().eq('list_id', list.id);
      _itemsByList[list.id] = itemRows.map(CustomListItem.fromMap).toList();
    }
    notifyListeners();
    _subscribe(weddingId);
  }

  void _subscribe(String weddingId) {
    _listsChannel?.unsubscribe();
    _listsChannel = _client
        .channel('custom_lists:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'custom_lists',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: weddingId,
          ),
          callback: _handleListChange,
        )
        .subscribe();

    // custom_list_items has no wedding_id column (matches its owning list
    // instead), so this channel can't be filtered server-side by wedding --
    // subscribe unfiltered and drop rows for lists we don't know about.
    _itemsChannel?.unsubscribe();
    _itemsChannel = _client
        .channel('custom_list_items:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'custom_list_items',
          callback: _handleItemChange,
        )
        .subscribe();
  }

  void _handleListChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final list = CustomList.fromMap(payload.newRecord);
        final idx = _lists.indexWhere((l) => l.id == list.id);
        if (idx == -1) {
          _lists.add(list);
          _itemsByList.putIfAbsent(list.id, () => []);
        } else {
          _lists[idx] = list;
        }
        break;
      case PostgresChangeEvent.delete:
        final id = payload.oldRecord['id'] as String;
        _lists.removeWhere((l) => l.id == id);
        _itemsByList.remove(id);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void _handleItemChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final item = CustomListItem.fromMap(payload.newRecord);
        if (!_itemsByList.containsKey(item.listId)) return; // not one of our lists
        final list = _itemsByList[item.listId]!;
        final idx = list.indexWhere((i) => i.id == item.id);
        if (idx == -1) {
          list.add(item);
        } else {
          list[idx] = item;
        }
        break;
      case PostgresChangeEvent.delete:
        final id = payload.oldRecord['id'] as String;
        for (final list in _itemsByList.values) {
          list.removeWhere((i) => i.id == id);
        }
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<CustomList> addList({
    required String weddingId,
    required String name,
    String icon = 'list_alt',
    List<CustomFieldDef> fields = const [],
  }) async {
    final list = CustomList(
      id: const Uuid().v4(),
      weddingId: weddingId,
      name: name,
      icon: icon,
      fields: fields,
    );
    await _client.from('custom_lists').insert(list.toMap());
    return list;
  }

  Future<void> updateList(CustomList list) async {
    await _client.from('custom_lists').update(list.toMap()).eq('id', list.id);
  }

  Future<void> deleteList(String listId) async {
    // custom_list_items cascade-delete in Postgres via the FK.
    await _client.from('custom_lists').delete().eq('id', listId);
  }

  Future<void> addItem({
    required String listId,
    required Map<String, dynamic> values,
  }) async {
    final item = CustomListItem(
      id: const Uuid().v4(),
      listId: listId,
      values: values,
    );
    await _client.from('custom_list_items').insert(item.toMap());
  }

  Future<void> updateItem(CustomListItem item) async {
    await _client.from('custom_list_items').update(item.toMap()).eq('id', item.id);
  }

  Future<void> deleteItem(String listId, String itemId) async {
    await _client.from('custom_list_items').delete().eq('id', itemId);
  }

  @override
  void dispose() {
    _listsChannel?.unsubscribe();
    _itemsChannel?.unsubscribe();
    super.dispose();
  }
}
