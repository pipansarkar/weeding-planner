import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages Supabase-backed weddings, membership, invites, and per-section
/// access requests -- the Phase 1 foundation for real-time collaboration.
/// Separate from [WeddingProvider], which still manages the legacy local
/// sqflite-backed weddings until later phases migrate domain data to Supabase.
class AccessProvider extends ChangeNotifier {
  static const _activeCloudWeddingIdKey = 'active_cloud_wedding_id';

  final _client = Supabase.instance.client;
  RealtimeChannel? _weddingChannel;

  String? _cloudWeddingId;
  String? get cloudWeddingId => _cloudWeddingId;

  bool _restoring = false;
  bool get isRestoring => _restoring;

  /// All cloud weddings the current user belongs to (as owner or member),
  /// so the drawer can list them by couple name and let the user switch --
  /// the same person can own one wedding and be a guest in another.
  List<Map<String, dynamic>> _myWeddings = [];
  List<Map<String, dynamic>> get myWeddings => List.unmodifiable(_myWeddings);

  AccessProvider() {
    _restoreActiveWedding();
  }

  /// Fetches every wedding the current user is a member of, for the drawer's
  /// wedding switcher. Safe to call any time; does not touch the active
  /// wedding.
  Future<void> loadMyWeddings() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    final rows = await _client
        .from('wedding_members')
        .select('role, weddings(id, bride_name, groom_name)')
        .eq('user_id', uid);
    _myWeddings = List<Map<String, dynamic>>.from(rows)
        .where((r) => r['weddings'] != null)
        .toList();
    notifyListeners();
  }

  /// Switches the active cloud wedding to one the user already belongs to
  /// (owner or member) and persists the choice.
  Future<void> switchWedding(String weddingId) async {
    if (weddingId == _cloudWeddingId) return;
    await loadMembership(weddingId);
  }

  /// Couple display name ("Bride & Groom") for a row from [myWeddings],
  /// falling back gracefully if one or both names aren't set yet.
  static String coupleNameFor(Map<String, dynamic> myWeddingRow) {
    final wedding = myWeddingRow['weddings'] as Map<String, dynamic>;
    final bride = (wedding['bride_name'] as String?)?.trim() ?? '';
    final groom = (wedding['groom_name'] as String?)?.trim() ?? '';
    if (bride.isEmpty && groom.isEmpty) return 'Untitled Wedding';
    if (bride.isEmpty) return groom;
    if (groom.isEmpty) return bride;
    return '$bride & $groom';
  }

  /// On startup, restores the last-active cloud wedding from local storage.
  /// If nothing was saved (e.g. fresh install on a device with a still-valid
  /// anonymous session), falls back to auto-discovering the first wedding
  /// this user is already a member of, so a returning collaborator doesn't
  /// land on an empty "create a wedding" screen for no reason.
  Future<void> _restoreActiveWedding() async {
    _restoring = true;
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _restoring = false;
      notifyListeners();
      return;
    }
    await loadMyWeddings();
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_activeCloudWeddingIdKey);
    if (savedId != null) {
      try {
        await loadMembership(savedId);
        _restoring = false;
        notifyListeners();
        return;
      } catch (_) {
        // Saved wedding no longer accessible (removed, wedding deleted, etc.);
        // fall through to auto-discovery below.
      }
    }
    if (_myWeddings.isNotEmpty) {
      final firstId = _myWeddings.first['weddings']['id'] as String;
      await loadMembership(firstId);
    }
    _restoring = false;
    notifyListeners();
  }

  Map<String, dynamic>? _weddingInfo;
  String get brideName => _weddingInfo?['bride_name'] as String? ?? '';
  String get groomName => _weddingInfo?['groom_name'] as String? ?? '';
  DateTime? get weddingDate => _weddingInfo?['wedding_date'] != null
      ? DateTime.parse(_weddingInfo!['wedding_date'] as String)
      : null;
  String get currencyCode => _weddingInfo?['currency_code'] as String? ?? 'INR';

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> get members => List.unmodifiable(_members);

  List<Map<String, dynamic>> _sectionAccess = [];
  List<Map<String, dynamic>> get sectionAccess => List.unmodifiable(_sectionAccess);

  bool get isOwner {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    return _members.any((m) => m['user_id'] == uid && m['role'] == 'owner');
  }

  bool hasApprovedAccess(String section) {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    if (isOwner) return true;
    return _sectionAccess.any(
      (row) => row['user_id'] == uid && row['section'] == section && row['status'] == 'approved',
    );
  }

  /// Resolves a user id to a display label for attribution UI
  /// ("edited by X"), preferring their real display name and falling back
  /// to their relationship label (e.g. "Bride") if no name is set yet.
  String displayNameFor(String? userId) {
    if (userId == null) return 'Someone';
    final member = _members.cast<Map<String, dynamic>?>().firstWhere(
          (m) => m?['user_id'] == userId,
          orElse: () => null,
        );
    if (member == null) return 'Someone';
    final profileName = (member['profiles'] as Map<String, dynamic>?)?['display_name'] as String?;
    final relationship = member['relationship'] as String?;
    return profileName ?? relationship ?? 'Someone';
  }

  /// Approved sections for a given member, for showing "what can they edit"
  /// next to each person in the collaborators list.
  List<String> approvedSectionsFor(String userId) {
    return _sectionAccess
        .where((row) => row['user_id'] == userId && row['status'] == 'approved')
        .map((row) => row['section'] as String)
        .toList()
      ..sort();
  }

  String? accessStatusFor(String section) {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = _sectionAccess.cast<Map<String, dynamic>?>().firstWhere(
          (r) => r?['user_id'] == uid && r?['section'] == section,
          orElse: () => null,
        );
    return row?['status'] as String?;
  }

  /// Creates a brand-new cloud wedding owned by the current user.
  Future<String> createCloudWedding({
    String brideName = '',
    String groomName = '',
  }) async {
    // Direct INSERT into weddings via PostgREST consistently failed RLS
    // checks in this project even against a maximally permissive policy
    // (see migration 0008); routed through an RPC that performs the insert
    // itself instead, which is unaffected by whatever is wrong with
    // PostgREST's INSERT-time RLS enforcement here.
    final row = await _client.rpc('create_wedding', params: {
      'p_bride_name': brideName,
      'p_groom_name': groomName,
    }) as Map<String, dynamic>;
    _cloudWeddingId = row['id'] as String;
    notifyListeners();
    await loadMembership(_cloudWeddingId!);
    // The owner's wedding_members row is inserted server-side by a trigger in
    // the same transaction as the RPC above, so it's already committed by the
    // time this call returns -- but PostgREST has repeatedly shown read-after-
    // write lag against this schema (see migrations 0007/0008), and an
    // immediate select here has been observed to come back without the
    // caller's own membership row. Retry briefly rather than leaving the
    // owner stuck looking like an unrecognized member of their own wedding.
    var attempts = 0;
    while (!isOwner && attempts < 5) {
      await Future.delayed(const Duration(milliseconds: 300));
      await loadMembership(_cloudWeddingId!);
      attempts++;
    }
    return _cloudWeddingId!;
  }

  Future<void> loadMembership(String weddingId) async {
    _cloudWeddingId = weddingId;
    notifyListeners();
    _weddingInfo = await _client.from('weddings').select().eq('id', weddingId).maybeSingle();
    _members = List<Map<String, dynamic>>.from(
      await _client.from('wedding_members').select('*, profiles(display_name)').eq('wedding_id', weddingId),
    );
    _sectionAccess = List<Map<String, dynamic>>.from(
      await _client.from('section_access').select().eq('wedding_id', weddingId),
    );
    notifyListeners();
    _subscribeToWedding(weddingId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeCloudWeddingIdKey, weddingId);
    unawaited(loadMyWeddings());
  }

  void _subscribeToWedding(String weddingId) {
    _weddingChannel?.unsubscribe();
    _weddingChannel = _client
        .channel('weddings:$weddingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'weddings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: weddingId,
          ),
          callback: (payload) {
            _weddingInfo = payload.newRecord;
            notifyListeners();
            // Keeps the drawer's wedding switcher (which reads bride/groom
            // names from myWeddings, not weddingInfo) in sync after a name
            // edit -- otherwise it keeps showing "Untitled Wedding" until
            // the next unrelated loadMyWeddings() call.
            unawaited(loadMyWeddings());
          },
        )
        .subscribe();
  }

  /// Owner-only: updates bride/groom names, wedding date, and currency.
  /// Enforced server-side by the weddings_update RLS policy (is_wedding_owner).
  Future<void> updateWeddingInfo({
    String? brideName,
    String? groomName,
    DateTime? weddingDate,
    String? currencyCode,
  }) async {
    final weddingId = _cloudWeddingId!;
    final updates = <String, dynamic>{};
    if (brideName != null) updates['bride_name'] = brideName;
    if (groomName != null) updates['groom_name'] = groomName;
    if (weddingDate != null) updates['wedding_date'] = weddingDate.toIso8601String().split('T').first;
    if (currencyCode != null) updates['currency_code'] = currencyCode;
    if (updates.isEmpty) return;
    await _client.from('weddings').update(updates).eq('id', weddingId);
    // Realtime subscription echoes the change back and updates _weddingInfo;
    // no local mutation needed here.
  }

  /// Owner-only: generates a shareable invite code for the active cloud wedding.
  Future<String> createInvite({DateTime? expiresAt, int? maxUses}) async {
    final weddingId = _cloudWeddingId!;
    final uid = _client.auth.currentUser!.id;
    final code = _generateInviteCode();
    await _client.from('wedding_invites').insert({
      'wedding_id': weddingId,
      'invite_code': code,
      'created_by': uid,
      'expires_at': expiresAt?.toIso8601String(),
      'max_uses': maxUses,
    });
    return code;
  }

  /// Invitee-side: redeems an invite code, joining the wedding as a member.
  Future<String> acceptInvite(String inviteCode) async {
    final weddingId = await _client.rpc('accept_wedding_invite', params: {
      'p_invite_code': inviteCode.trim(),
    }) as String;
    await loadMembership(weddingId);
    return weddingId;
  }

  /// Requests standing access to a section (or re-requests after a rejection
  /// or revocation); owner must approve before writes succeed.
  Future<void> requestSectionAccess(String section) async {
    final weddingId = _cloudWeddingId!;
    await _client.rpc('request_section_access', params: {
      'p_wedding_id': weddingId,
      'p_section': section,
    });
    await loadMembership(weddingId);
  }

  /// Owner-only: approve, reject, or revoke a member's access to a section.
  Future<void> decideSectionAccess(String accessRowId, String status) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('section_access').update({
      'status': status,
      'decided_at': DateTime.now().toIso8601String(),
      'decided_by': uid,
    }).eq('id', accessRowId);
    await loadMembership(_cloudWeddingId!);
  }

  /// Owner-only: grants a member access to a section directly, without them
  /// having requested it first.
  Future<void> grantSectionAccess(String userId, String section) async {
    final weddingId = _cloudWeddingId!;
    await _client.rpc('grant_section_access', params: {
      'p_wedding_id': weddingId,
      'p_user_id': userId,
      'p_section': section,
    });
    await loadMembership(weddingId);
  }

  /// Owner-only: fully removes a member from the wedding (all section access
  /// revoked and their membership row deleted), not just one section.
  Future<void> removeMember(String userId) async {
    final weddingId = _cloudWeddingId!;
    await _client.rpc('remove_wedding_member', params: {
      'p_wedding_id': weddingId,
      'p_user_id': userId,
    });
    await loadMembership(weddingId);
  }

  /// Owner-only: permanently deletes the wedding and everything in it
  /// (checklist, budget, guests, vendors, timeline, etc. all cascade via the
  /// weddings row) then clears local state so the app stops pointing at it.
  Future<void> deleteWedding(String weddingId) async {
    await _client.rpc('delete_wedding', params: {'p_wedding_id': weddingId});
    if (_cloudWeddingId == weddingId) {
      _clearActiveWedding();
    }
    await loadMyWeddings();
  }

  /// Clears cached cloud-wedding state and the persisted active-wedding pref,
  /// without touching the user's session. Used after deleting or resetting
  /// the active cloud wedding so stale state doesn't linger.
  Future<void> _clearActiveWedding() async {
    _weddingChannel?.unsubscribe();
    _weddingChannel = null;
    _cloudWeddingId = null;
    _weddingInfo = null;
    _members = [];
    _sectionAccess = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeCloudWeddingIdKey);
    notifyListeners();
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    var seed = rand;
    for (var i = 0; i < 8; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buffer.write(chars[seed % chars.length]);
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _weddingChannel?.unsubscribe();
    super.dispose();
  }
}
