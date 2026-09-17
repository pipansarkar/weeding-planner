import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/emergency_contact.dart';

class EmergencyContactProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;

  final List<EmergencyContact> _contacts = [];
  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);

  Future<void> load({required String weddingId}) async {
    final rows = await _client
        .from('emergency_contacts')
        .select()
        .eq('wedding_id', weddingId)
        .order('name');
    _contacts
      ..clear()
      ..addAll(rows.map(EmergencyContact.fromMap));
    notifyListeners();
    _subscribe(weddingId);
  }

  void _subscribe(String weddingId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('emergency_contacts:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'emergency_contacts',
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
        final contact = EmergencyContact.fromMap(payload.newRecord);
        final idx = _contacts.indexWhere((e) => e.id == contact.id);
        if (idx == -1) {
          _contacts.add(contact);
        } else {
          _contacts[idx] = contact;
        }
        break;
      case PostgresChangeEvent.delete:
        _contacts.removeWhere((e) => e.id == payload.oldRecord['id']);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> add({
    required String weddingId,
    required String name,
    String role = '',
    String phone = '',
  }) async {
    final contact = EmergencyContact(
      id: const Uuid().v4(),
      weddingId: weddingId,
      name: name,
      role: role,
      phone: phone,
    );
    await _client.from('emergency_contacts').insert(contact.toMap());
  }

  Future<void> update(EmergencyContact contact) async {
    await _client.from('emergency_contacts').update(contact.toMap()).eq('id', contact.id);
  }

  Future<void> delete(String id) async {
    await _client.from('emergency_contacts').delete().eq('id', id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
