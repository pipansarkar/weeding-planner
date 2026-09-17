import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/vendor.dart';
import '../models/vendor_contact_log.dart';

class VendorProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  RealtimeChannel? _vendorsChannel;
  RealtimeChannel? _logsChannel;

  final List<Vendor> _vendors = [];
  List<Vendor> get vendors => List.unmodifiable(_vendors);

  final List<VendorContactLog> _contactLogs = [];
  List<VendorContactLog> get contactLogs => List.unmodifiable(_contactLogs);

  int countForStatus(VendorStatus status) =>
      _vendors.where((v) => v.status == status).length;

  Map<String, List<Vendor>> get vendorsByCategory {
    final map = <String, List<Vendor>>{};
    for (final v in _vendors) {
      map.putIfAbsent(v.category, () => []).add(v);
    }
    return map;
  }

  List<VendorContactLog> logsForVendor(String vendorId) => _contactLogs
      .where((l) => l.vendorId == vendorId)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> load({required String weddingId}) async {
    final vendorRows = await _client
        .from('vendors')
        .select()
        .eq('wedding_id', weddingId)
        .order('name');
    _vendors
      ..clear()
      ..addAll(vendorRows.map(Vendor.fromMap));

    final logRows = await _client
        .from('vendor_contact_logs')
        .select()
        .eq('wedding_id', weddingId)
        .order('date', ascending: false);
    _contactLogs
      ..clear()
      ..addAll(logRows.map(VendorContactLog.fromMap));

    notifyListeners();
    _subscribe(weddingId);
  }

  void _subscribe(String weddingId) {
    _vendorsChannel?.unsubscribe();
    _vendorsChannel = _client
        .channel('vendors:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vendors',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: weddingId,
          ),
          callback: _handleVendorChange,
        )
        .subscribe();

    _logsChannel?.unsubscribe();
    _logsChannel = _client
        .channel('vendor_contact_logs:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vendor_contact_logs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: weddingId,
          ),
          callback: _handleLogChange,
        )
        .subscribe();
  }

  void _handleVendorChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final vendor = Vendor.fromMap(payload.newRecord);
        final idx = _vendors.indexWhere((e) => e.id == vendor.id);
        if (idx == -1) {
          _vendors.add(vendor);
        } else {
          _vendors[idx] = vendor;
        }
        break;
      case PostgresChangeEvent.delete:
        _vendors.removeWhere((e) => e.id == payload.oldRecord['id']);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void _handleLogChange(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        final log = VendorContactLog.fromMap(payload.newRecord);
        final idx = _contactLogs.indexWhere((e) => e.id == log.id);
        if (idx == -1) {
          _contactLogs.add(log);
        } else {
          _contactLogs[idx] = log;
        }
        break;
      case PostgresChangeEvent.delete:
        _contactLogs.removeWhere((e) => e.id == payload.oldRecord['id']);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> add({
    required String weddingId,
    required String name,
    required String category,
    String phone = '',
    String site = '',
    String address = '',
    double amount = 0,
    VendorStatus status = VendorStatus.pending,
    String note = '',
  }) async {
    final vendor = Vendor(
      id: const Uuid().v4(),
      weddingId: weddingId,
      name: name,
      category: category,
      phone: phone,
      site: site,
      address: address,
      amount: amount,
      status: status,
      note: note,
    );
    await _client.from('vendors').insert(vendor.toMap());
  }

  Future<void> update(Vendor vendor) async {
    await _client.from('vendors').update(vendor.toMap()).eq('id', vendor.id);
  }

  Future<void> delete(String id) async {
    // vendor_contact_logs cascade-delete in Postgres via the FK, so no separate call is needed.
    await _client.from('vendors').delete().eq('id', id);
  }

  Future<void> addContactLog({
    required String weddingId,
    required String vendorId,
    required DateTime date,
    String note = '',
  }) async {
    final log = VendorContactLog(
      id: const Uuid().v4(),
      weddingId: weddingId,
      vendorId: vendorId,
      date: date,
      note: note,
    );
    await _client.from('vendor_contact_logs').insert(log.toMap());
  }

  Future<void> deleteContactLog(String id) async {
    await _client.from('vendor_contact_logs').delete().eq('id', id);
  }

  @override
  void dispose() {
    _vendorsChannel?.unsubscribe();
    _logsChannel?.unsubscribe();
    super.dispose();
  }
}
