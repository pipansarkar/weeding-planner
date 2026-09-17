import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/timeline_event.dart';

class TimelineProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;

  final List<TimelineEvent> _events = [];
  List<TimelineEvent> get events {
    final list = List<TimelineEvent>.from(_events);
    list.sort((a, b) => a.time.compareTo(b.time));
    return List.unmodifiable(list);
  }

  Future<void> load({required String weddingId}) async {
    final rows = await _client.from('timeline_events').select().eq('wedding_id', weddingId);
    _events
      ..clear()
      ..addAll(rows.map(TimelineEvent.fromMap));
    notifyListeners();
    _subscribe(weddingId);
  }

  void _subscribe(String weddingId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('timeline_events:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'timeline_events',
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
        final event = TimelineEvent.fromMap(payload.newRecord);
        final idx = _events.indexWhere((e) => e.id == event.id);
        if (idx == -1) {
          _events.add(event);
        } else {
          _events[idx] = event;
        }
        break;
      case PostgresChangeEvent.delete:
        _events.removeWhere((e) => e.id == payload.oldRecord['id']);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> add({
    required String weddingId,
    required String title,
    String category = 'Other',
    required DateTime time,
    String note = '',
  }) async {
    final event = TimelineEvent(
      id: const Uuid().v4(),
      weddingId: weddingId,
      title: title,
      category: category,
      time: time,
      note: note,
    );
    await _client.from('timeline_events').insert(event.toMap());
  }

  Future<void> addAll(List<TimelineEvent> newEvents) async {
    if (newEvents.isEmpty) return;
    await _client.from('timeline_events').insert(newEvents.map((e) => e.toMap()).toList());
  }

  Future<void> update(TimelineEvent event) async {
    await _client.from('timeline_events').update(event.toMap()).eq('id', event.id);
  }

  Future<void> delete(String id) async {
    await _client.from('timeline_events').delete().eq('id', id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
