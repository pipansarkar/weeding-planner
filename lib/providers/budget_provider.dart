import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/budget_item.dart';

class BudgetProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;

  final List<BudgetItem> _items = [];
  List<BudgetItem> get items => List.unmodifiable(_items);

  double get totalEstimated =>
      _items.fold(0, (sum, e) => sum + e.estimatedAmount);
  double get totalActual => _items.fold(0, (sum, e) => sum + e.actualAmount);

  List<BudgetItem> get upcomingPayments {
    final now = DateTime.now();
    final list = _items
        .where((e) =>
            e.dueDate != null &&
            e.paymentStatus != PaymentStatus.paidInFull)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return list.where((e) => !e.dueDate!.isBefore(DateTime(now.year, now.month, now.day))).toList();
  }

  List<BudgetItem> get overduePayments {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _items
        .where((e) =>
            e.dueDate != null &&
            e.paymentStatus != PaymentStatus.paidInFull &&
            e.dueDate!.isBefore(today))
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  Map<String, double> get estimatedByCategory {
    final map = <String, double>{};
    for (final item in _items) {
      map[item.category] = (map[item.category] ?? 0) + item.estimatedAmount;
    }
    return map;
  }

  Map<String, double> get actualByCategory {
    final map = <String, double>{};
    for (final item in _items) {
      map[item.category] = (map[item.category] ?? 0) + item.actualAmount;
    }
    return map;
  }

  Future<void> load({required String weddingId}) async {
    final rows = await _client
        .from('budget_items')
        .select()
        .eq('wedding_id', weddingId)
        .order('category');
    _items
      ..clear()
      ..addAll(rows.map(BudgetItem.fromMap));
    notifyListeners();
    _subscribe(weddingId);
  }

  void _subscribe(String weddingId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('budget_items:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'budget_items',
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
        final item = BudgetItem.fromMap(payload.newRecord);
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
    double estimatedAmount = 0,
    double actualAmount = 0,
    String note = '',
    DateTime? dueDate,
    String paymentMethod = '',
    String paidBy = '',
    PaymentStatus paymentStatus = PaymentStatus.unpaid,
  }) async {
    final item = BudgetItem(
      id: const Uuid().v4(),
      weddingId: weddingId,
      name: name,
      category: category,
      estimatedAmount: estimatedAmount,
      actualAmount: actualAmount,
      note: note,
      dueDate: dueDate,
      paymentMethod: paymentMethod,
      paidBy: paidBy,
      paymentStatus: paymentStatus,
    );
    await _client.from('budget_items').insert(item.toMap());
    return item.id;
  }

  Future<void> update(BudgetItem item) async {
    await _client.from('budget_items').update(item.toMap()).eq('id', item.id);
  }

  Future<void> delete(String id) async {
    await _client.from('budget_items').delete().eq('id', id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
