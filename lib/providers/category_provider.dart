import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/budget_item.dart';
import '../models/checklist_item.dart';
import '../models/guest.dart';
import '../models/timeline_event.dart';
import '../models/vendor.dart';

/// The sections that support user-added custom categories, alongside
/// each one's built-in fixed list to merge with.
const Map<String, List<String>> builtInCategoriesBySection = {
  'budget': BudgetItem.categories,
  'vendors': Vendor.categories,
  'checklist': ChecklistItem.categories,
  'timeline': TimelineEvent.categories,
  'guests': Guest.eventTypes,
};

const Map<String, String> categorySectionLabels = {
  'budget': 'Budget',
  'vendors': 'Vendors',
  'checklist': 'Checklist',
  'timeline': 'Schedule',
  'guests': 'Guest Events',
};

/// Manages per-wedding, per-section custom categories (on top of each
/// section's built-in fixed list) and which built-ins this wedding has
/// hidden, shared live with all collaborators.
class CategoryProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;
  RealtimeChannel? _hiddenChannel;
  String? _weddingId;

  final List<Map<String, dynamic>> _rows = [];
  final List<Map<String, dynamic>> _hiddenRows = [];

  /// Built-in categories (minus any this wedding has hidden) plus any custom
  /// ones added for [section], in that order, with duplicates (case-
  /// insensitive) removed.
  List<String> categoriesFor(String section) {
    final hidden = _hiddenRows
        .where((r) => r['section'] == section)
        .map((r) => (r['name'] as String).toLowerCase())
        .toSet();
    final builtIn = (builtInCategoriesBySection[section] ?? const [])
        .where((c) => !hidden.contains(c.toLowerCase()));
    final custom = _rows
        .where((r) => r['section'] == section)
        .map((r) => r['name'] as String);
    final seen = <String>{};
    final result = <String>[];
    for (final c in [...builtIn, ...custom]) {
      if (seen.add(c.toLowerCase())) result.add(c);
    }
    return result;
  }

  /// Only the custom (user-added) categories for [section], for management UI.
  List<Map<String, dynamic>> customFor(String section) {
    return _rows.where((r) => r['section'] == section).toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  /// This wedding's built-in categories for [section] that haven't been
  /// hidden, alongside the ones that have -- for the management UI, which
  /// shows every built-in with a toggle rather than just a fixed chip list.
  List<String> visibleBuiltInsFor(String section) {
    final hidden = hiddenBuiltInsFor(section).map((n) => n.toLowerCase()).toSet();
    return (builtInCategoriesBySection[section] ?? const [])
        .where((c) => !hidden.contains(c.toLowerCase()))
        .toList();
  }

  List<String> hiddenBuiltInsFor(String section) {
    return _hiddenRows
        .where((r) => r['section'] == section)
        .map((r) => r['name'] as String)
        .toList()
      ..sort();
  }

  Future<void> load({required String weddingId}) async {
    _weddingId = weddingId;
    final rows = await _client
        .from('custom_categories')
        .select()
        .eq('wedding_id', weddingId);
    _rows
      ..clear()
      ..addAll(List<Map<String, dynamic>>.from(rows));
    notifyListeners();
    _subscribe(weddingId);
    try {
      // Separate try/catch: hidden_categories is a newer table, so a
      // wedding whose Supabase project hasn't had that migration applied
      // yet would otherwise throw here and skip the notifyListeners() above,
      // silently hiding every already-loaded custom category from the UI.
      final hiddenRows = await _client
          .from('hidden_categories')
          .select()
          .eq('wedding_id', weddingId);
      _hiddenRows
        ..clear()
        ..addAll(List<Map<String, dynamic>>.from(hiddenRows));
      notifyListeners();
      _subscribeHidden(weddingId);
    } catch (_) {
      // hidden_categories not available yet -- built-ins just won't be
      // hideable until the migration runs; custom categories still work.
    }
  }

  void _subscribe(String weddingId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('custom_categories:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'custom_categories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: weddingId,
          ),
          callback: _handleRealtimeChange,
        )
        .subscribe();
  }

  void _subscribeHidden(String weddingId) {
    _hiddenChannel?.unsubscribe();
    _hiddenChannel = _client
        .channel('hidden_categories:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'hidden_categories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: weddingId,
          ),
          callback: _handleHiddenRealtimeChange,
        )
        .subscribe();
  }

  void _handleRealtimeChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        if (!_rows.any((r) => r['id'] == payload.newRecord['id'])) {
          _rows.add(payload.newRecord);
        }
        break;
      case PostgresChangeEvent.delete:
        _rows.removeWhere((r) => r['id'] == payload.oldRecord['id']);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void _handleHiddenRealtimeChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        // Dedupe by section+name, not id -- hideBuiltIn() already added an
        // optimistic row with a synthetic id before this echo arrives, so
        // matching on id alone would let the real row through as a
        // duplicate chip.
        final newRecord = payload.newRecord;
        _hiddenRows.removeWhere(
          (r) => r['section'] == newRecord['section'] && r['name'] == newRecord['name'],
        );
        _hiddenRows.add(newRecord);
        break;
      case PostgresChangeEvent.delete:
        _hiddenRows.removeWhere((r) => r['id'] == payload.oldRecord['id']);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  /// Adds a new custom category to [section]; no-ops if it already exists
  /// (built-in or custom, case-insensitive).
  Future<void> addCategory(String section, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _weddingId == null) return;
    if (categoriesFor(section).any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      return;
    }
    final uid = _client.auth.currentUser?.id;
    await _client.from('custom_categories').insert({
      'wedding_id': _weddingId,
      'section': section,
      'name': trimmed,
      'created_by': uid,
    });
  }

  Future<void> removeCategory(String id) async {
    // Removed locally right away rather than waiting for the realtime echo
    // to come back -- that round trip left the chip visibly lingering in
    // the UI for a beat (or indefinitely, if the realtime channel hiccups)
    // after the user already confirmed the delete.
    final removed = _rows.where((r) => r['id'] == id).toList();
    _rows.removeWhere((r) => r['id'] == id);
    notifyListeners();
    try {
      await _client.from('custom_categories').delete().eq('id', id);
    } catch (_) {
      _rows.addAll(removed);
      notifyListeners();
      rethrow;
    }
  }

  /// Hides one of the app's built-in categories for this wedding so it's no
  /// longer offered for new items. Existing items already using it keep it.
  Future<void> hideBuiltIn(String section, String name) async {
    if (_weddingId == null) return;
    final uid = _client.auth.currentUser?.id;
    final optimisticRow = {
      'id': '_pending_${section}_$name',
      'wedding_id': _weddingId,
      'section': section,
      'name': name,
      'hidden_by': uid,
    };
    _hiddenRows.add(optimisticRow);
    notifyListeners();
    try {
      await _client.from('hidden_categories').insert({
        'wedding_id': _weddingId,
        'section': section,
        'name': name,
        'hidden_by': uid,
      });
    } catch (_) {
      _hiddenRows.remove(optimisticRow);
      notifyListeners();
      rethrow;
    }
  }

  /// Restores a previously hidden built-in category.
  Future<void> unhideBuiltIn(String section, String name) async {
    if (_weddingId == null) return;
    final removed = _hiddenRows
        .where((r) => r['section'] == section && r['name'] == name)
        .toList();
    _hiddenRows.removeWhere((r) => r['section'] == section && r['name'] == name);
    notifyListeners();
    try {
      await _client
          .from('hidden_categories')
          .delete()
          .eq('wedding_id', _weddingId!)
          .eq('section', section)
          .eq('name', name);
    } catch (_) {
      _hiddenRows.addAll(removed);
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _hiddenChannel?.unsubscribe();
    super.dispose();
  }
}
