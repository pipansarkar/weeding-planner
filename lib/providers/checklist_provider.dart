import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/checklist_item.dart';

class ChecklistProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;

  final List<ChecklistItem> _items = [];
  List<ChecklistItem> get items => List.unmodifiable(_items);

  int get completedCount =>
      _items.where((e) => e.status == ChecklistStatus.completed).length;
  int get pendingCount =>
      _items.where((e) => e.status == ChecklistStatus.pending).length;

  Future<void> load({required String weddingId}) async {
    final rows = await _client
        .from('checklist_items')
        .select()
        .eq('wedding_id', weddingId)
        .order('date');
    _items
      ..clear()
      ..addAll(rows.map(ChecklistItem.fromMap));
    notifyListeners();
    _subscribe(weddingId);
  }

  void _subscribe(String weddingId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('checklist_items:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'checklist_items',
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
        final item = ChecklistItem.fromMap(payload.newRecord);
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

  Future<String> add({
    required String weddingId,
    required String name,
    required String category,
    DateTime? date,
    String note = '',
    ChecklistStatus status = ChecklistStatus.pending,
  }) async {
    final item = ChecklistItem(
      id: const Uuid().v4(),
      weddingId: weddingId,
      name: name,
      category: category,
      date: date,
      note: note,
      status: status,
    );
    await _client.from('checklist_items').insert(item.toMap());
    return item.id;
  }

  Future<void> update(ChecklistItem item) async {
    await _client.from('checklist_items').update(item.toMap()).eq('id', item.id);
  }

  Future<void> toggleStatus(ChecklistItem item) async {
    final newStatus = item.status == ChecklistStatus.completed
        ? ChecklistStatus.pending
        : ChecklistStatus.completed;
    await update(item.copyWith(status: newStatus));
  }

  Future<void> delete(String id) async {
    await _client.from('checklist_items').delete().eq('id', id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
