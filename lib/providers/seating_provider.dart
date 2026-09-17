import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/seating_table.dart';

class SeatingProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  RealtimeChannel? _tablesChannel;
  RealtimeChannel? _assignmentsChannel;

  final Map<String, Map<String, dynamic>> _tableRows = {};
  // tableId -> set of assigned guestIds
  final Map<String, Set<String>> _assignments = {};
  // assignmentId -> (tableId, guestId), so realtime deletes can find which table to update
  final Map<String, (String, String)> _assignmentIndex = {};

  List<SeatingTable> get tables {
    final list = _tableRows.values
        .map((row) => SeatingTable.fromMap(
              row,
              guestIds: (_assignments[row['id'] as String] ?? const <String>{}).toList(),
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(list);
  }

  Set<String> get seatedGuestIds => _assignments.values.expand((s) => s).toSet();

  Future<void> load({required String weddingId}) async {
    final tableRows = await _client
        .from('seating_tables')
        .select()
        .eq('wedding_id', weddingId)
        .order('name');
    _tableRows
      ..clear()
      ..addEntries(
        List<Map<String, dynamic>>.from(tableRows).map((r) => MapEntry(r['id'] as String, r)),
      );

    final assignmentRows = await _client
        .from('seating_assignments')
        .select()
        .eq('wedding_id', weddingId);
    _assignments.clear();
    _assignmentIndex.clear();
    for (final row in List<Map<String, dynamic>>.from(assignmentRows)) {
      final tableId = row['table_id'] as String;
      final guestId = row['guest_id'] as String;
      _assignments.putIfAbsent(tableId, () => {}).add(guestId);
      _assignmentIndex[row['id'] as String] = (tableId, guestId);
    }

    notifyListeners();
    _subscribe(weddingId);
  }

  void _subscribe(String weddingId) {
    _tablesChannel?.unsubscribe();
    _tablesChannel = _client
        .channel('seating_tables:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'seating_tables',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: weddingId,
          ),
          callback: _handleTableChange,
        )
        .subscribe();

    _assignmentsChannel?.unsubscribe();
    _assignmentsChannel = _client
        .channel('seating_assignments:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'seating_assignments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: weddingId,
          ),
          callback: _handleAssignmentChange,
        )
        .subscribe();
  }

  void _handleTableChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final row = payload.newRecord;
        _tableRows[row['id'] as String] = row;
        break;
      case PostgresChangeEvent.delete:
        final id = payload.oldRecord['id'] as String;
        _tableRows.remove(id);
        _assignments.remove(id);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void _handleAssignmentChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final row = payload.newRecord;
        final tableId = row['table_id'] as String;
        final guestId = row['guest_id'] as String;
        _assignments.putIfAbsent(tableId, () => {}).add(guestId);
        _assignmentIndex[row['id'] as String] = (tableId, guestId);
        break;
      case PostgresChangeEvent.delete:
        final assignmentId = payload.oldRecord['id'] as String;
        final indexed = _assignmentIndex.remove(assignmentId);
        if (indexed != null) {
          _assignments[indexed.$1]?.remove(indexed.$2);
        }
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> add({
    required String weddingId,
    required String name,
    int capacity = 8,
  }) async {
    final table = SeatingTable(
      id: const Uuid().v4(),
      weddingId: weddingId,
      name: name,
      capacity: capacity,
    );
    await _client.from('seating_tables').insert(table.toMap());
  }

  Future<void> update(SeatingTable table) async {
    await _client.from('seating_tables').update(table.toMap()).eq('id', table.id);
  }

  Future<void> assignGuest(String tableId, String guestId) async {
    if (_assignments[tableId]?.contains(guestId) ?? false) return;
    final tableRow = _tableRows[tableId];
    if (tableRow == null) return;
    await _client.from('seating_assignments').insert({
      'id': const Uuid().v4(),
      'wedding_id': tableRow['wedding_id'],
      'table_id': tableId,
      'guest_id': guestId,
    });
  }

  Future<void> unassignGuest(String tableId, String guestId) async {
    await _client
        .from('seating_assignments')
        .delete()
        .eq('table_id', tableId)
        .eq('guest_id', guestId);
  }

  Future<void> delete(String id) async {
    // seating_assignments cascade-delete in Postgres via the FK.
    await _client.from('seating_tables').delete().eq('id', id);
  }

  @override
  void dispose() {
    _tablesChannel?.unsubscribe();
    _assignmentsChannel?.unsubscribe();
    super.dispose();
  }
}
