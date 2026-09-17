import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/guest.dart';

class GuestProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;
  RealtimeChannel? _channel;

  final List<Guest> _guests = [];
  List<Guest> get guests => List.unmodifiable(_guests);

  int get totalCount => _guests.length;

  int get totalHeadcount => _guests.fold(0, (sum, g) => sum + g.totalHeadcount);

  int countForEvent(String event) =>
      _guests.where((g) => g.events.contains(event)).length;

  int attendingHeadcountForEvent(String event) => _guests
      .where((g) => g.events.contains(event) && g.rsvpFor(event) == RsvpStatus.attending)
      .fold(0, (sum, g) => sum + g.totalHeadcount);

  int rsvpCountForEvent(String event, RsvpStatus status) => _guests
      .where((g) => g.events.contains(event) && g.rsvpFor(event) == status)
      .length;

  int get invitationsSentCount => _guests.where((g) => g.invitationSent).length;

  int get giftsPendingThankYouCount =>
      _guests.where((g) => g.giftReceived.isNotEmpty && !g.thankYouSent).length;

  Future<void> load({required String weddingId}) async {
    final rows = await _client
        .from('guests')
        .select()
        .eq('wedding_id', weddingId)
        .order('name');
    _guests
      ..clear()
      ..addAll(rows.map(Guest.fromMap));
    notifyListeners();
    _subscribe(weddingId);
  }

  void _subscribe(String weddingId) {
    _channel?.unsubscribe();
    _channel = _client
        .channel('guests:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'guests',
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
        final guest = Guest.fromMap(payload.newRecord);
        final idx = _guests.indexWhere((g) => g.id == guest.id);
        if (idx == -1) {
          _guests.add(guest);
        } else {
          _guests[idx] = guest;
        }
        break;
      case PostgresChangeEvent.delete:
        _guests.removeWhere((g) => g.id == payload.oldRecord['id']);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> add({
    required String weddingId,
    required String name,
    required Gender gender,
    String phone = '',
    String address = '',
    String note = '',
    required String category,
    Set<String> events = const {},
    Map<String, RsvpStatus> rsvpByEvent = const {},
    int plusOnes = 0,
    String mealPreference = '',
    bool invitationSent = false,
    String giftReceived = '',
    bool thankYouSent = false,
  }) async {
    final guest = Guest(
      id: const Uuid().v4(),
      weddingId: weddingId,
      name: name,
      gender: gender,
      phone: phone,
      address: address,
      note: note,
      category: category,
      events: events,
      rsvpByEvent: rsvpByEvent,
      plusOnes: plusOnes,
      mealPreference: mealPreference,
      invitationSent: invitationSent,
      giftReceived: giftReceived,
      thankYouSent: thankYouSent,
    );
    await _client.from('guests').insert(guest.toMap());
    // Realtime echoes the insert back and updates _guests; no local mutation here.
  }

  Future<void> update(Guest guest) async {
    await _client.from('guests').update(guest.toMap()).eq('id', guest.id);
  }

  Future<void> delete(String id) async {
    await _client.from('guests').delete().eq('id', id);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String toCsv() {
    final header = [
      'Name',
      'Gender',
      'Phone',
      'Address',
      'Category',
      'Events',
      'Plus Ones',
      'Meal Preference',
      'Invitation Sent',
      'Gift Received',
      'Thank You Sent',
      'Note',
    ].join(',');
    final rows = _guests.map((g) {
      return [
        g.name,
        g.gender.name,
        g.phone,
        g.address,
        g.category,
        g.events.join('; '),
        g.plusOnes.toString(),
        g.mealPreference,
        g.invitationSent ? 'Yes' : 'No',
        g.giftReceived,
        g.thankYouSent ? 'Yes' : 'No',
        g.note,
      ].map(_csvEscape).join(',');
    });
    return ([header] + rows.toList()).join('\n');
  }
}
