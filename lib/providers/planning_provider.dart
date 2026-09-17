import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/budget_item.dart';
import '../models/planning_item.dart';
import 'budget_provider.dart';

/// Manages the Planning screen's items (Accommodation, Transportation,
/// Jewelry, Food, Ceremony & Venue, Decoration & Flower) -- the
/// who/what/how-many/price side of each category, distinct from Vendors
/// (the supplier side) and Checklist (a flat to-do). Takes a [BudgetProvider]
/// so a priced item's cost stays mirrored into a linked Budget entry.
class PlanningProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  final BudgetProvider _budget;
  RealtimeChannel? _channel;

  PlanningProvider(this._budget);

  final List<PlanningItem> _items = [];
  List<PlanningItem> get items => List.unmodifiable(_items);

  List<PlanningItem> forCategory(PlanningCategory category) =>
      _items.where((e) => e.category == category).toList();

  double totalForCategory(PlanningCategory category) => _items
      .where((e) => e.category == category)
      .fold(0, (sum, e) => sum + e.totalPrice);

  Future<void> load({required String weddingId}) async {
    final rows = await _client
        .from('planning_items')
        .select()
        .eq('wedding_id', weddingId)
        .order('title');
    _items
      ..clear()
      ..addAll(rows.map(PlanningItem.fromMap));
    notifyListeners();
    _subscribe(weddingId);
  }

  void _subscribe(String weddingId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('planning_items:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'planning_items',
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
        final item = PlanningItem.fromMap(payload.newRecord);
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

  /// Inserts/updates/clears the Budget entry mirrored from a planning item's
  /// price, returning the budget_item_id to store back on the planning row
  /// (null once the item has no price left to track).
  Future<String?> _syncBudget({
    required String weddingId,
    required PlanningItem item,
    String? existingBudgetItemId,
  }) async {
    if (item.totalPrice <= 0) {
      if (existingBudgetItemId != null) {
        await _budget.delete(existingBudgetItemId);
      }
      return null;
    }
    if (existingBudgetItemId != null) {
      final existing = _budget.items.where((b) => b.id == existingBudgetItemId);
      if (existing.isNotEmpty) {
        await _budget.update(existing.first.copyWith(
          name: item.title,
          category: item.category.budgetCategory,
          estimatedAmount: item.totalPrice,
          actualAmount: item.status == PlanningStatus.purchased || item.status == PlanningStatus.done
              ? item.totalPrice
              : existing.first.actualAmount,
        ));
        return existingBudgetItemId;
      }
    }
    return _budget.add(
      weddingId: weddingId,
      name: item.title,
      category: item.category.budgetCategory,
      estimatedAmount: item.totalPrice,
      actualAmount: item.status == PlanningStatus.purchased || item.status == PlanningStatus.done
          ? item.totalPrice
          : 0,
      paymentStatus: item.status == PlanningStatus.purchased || item.status == PlanningStatus.done
          ? PaymentStatus.paidInFull
          : PaymentStatus.unpaid,
    );
  }

  Future<String> add(PlanningItem draft) async {
    final id = const Uuid().v4();
    var item = PlanningItem(
      id: id,
      weddingId: draft.weddingId,
      category: draft.category,
      title: draft.title,
      guestId: draft.guestId,
      forCouple: draft.forCouple,
      vendorId: draft.vendorId,
      quantity: draft.quantity,
      unitPrice: draft.unitPrice,
      status: draft.status,
      note: draft.note,
      eventName: draft.eventName,
      venueName: draft.venueName,
      address: draft.address,
      eventDate: draft.eventDate,
      startDate: draft.startDate,
      endDate: draft.endDate,
      fromLocation: draft.fromLocation,
      toLocation: draft.toLocation,
      vehicleType: draft.vehicleType,
      occasion: draft.occasion,
      course: draft.course,
      placement: draft.placement,
    );
    final budgetItemId = await _syncBudget(weddingId: draft.weddingId, item: item);
    item = item.copyWith(budgetItemId: budgetItemId);
    await _client.from('planning_items').insert(item.toMap());
    return id;
  }

  Future<void> update(PlanningItem item) async {
    final budgetItemId = await _syncBudget(
      weddingId: item.weddingId,
      item: item,
      existingBudgetItemId: item.budgetItemId,
    );
    final updated = item.copyWith(
      budgetItemId: budgetItemId,
      clearBudgetItemId: budgetItemId == null,
    );
    await _client.from('planning_items').update(updated.toMap()).eq('id', item.id);
  }

  Future<void> delete(String id) async {
    final existing = _items.where((e) => e.id == id);
    if (existing.isNotEmpty && existing.first.budgetItemId != null) {
      await _budget.delete(existing.first.budgetItemId!);
    }
    await _client.from('planning_items').delete().eq('id', id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
