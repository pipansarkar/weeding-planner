import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;

  Session? _session;
  Session? get session => _session;
  bool get isSignedIn => _session != null;
  String? get userId => _session?.user.id;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? get profile => _profile;
  String? get displayName => _profile?['display_name'] as String?;

  bool _loading = false;
  bool get loading => _loading;

  // True from the moment a session is found until its profile row has been
  // fetched. AuthGate watches this so it doesn't briefly flash
  // SetDisplayNameScreen for a returning user while displayName is still
  // null only because the profile fetch hasn't resolved yet.
  bool _profileLoading = false;
  bool get profileLoading => _profileLoading;

  String? _lastError;
  String? get lastError => _lastError;

  AuthProvider() {
    _session = _client.auth.currentSession;
    if (_session != null) _loadProfile();
    _client.auth.onAuthStateChange.listen((data) {
      _session = data.session;
      if (_session != null) {
        _loadProfile();
      } else {
        _profile = null;
        _profileLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfile() async {
    final uid = userId;
    if (uid == null) return;
    _profileLoading = true;
    notifyListeners();
    final row = await _client.from('profiles').select().eq('id', uid).maybeSingle();
    _profile = row;
    _profileLoading = false;
    notifyListeners();
  }

  /// One-tap entry: no email, no password. Requires "Anonymous Sign-Ins" to
  /// be enabled in the Supabase dashboard (Authentication > Providers).
  /// The person picks a display name afterward via SetDisplayNameScreen.
  Future<bool> continueAnonymously() async {
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      await _client.auth.signInAnonymously();
      return true;
    } on AuthException catch (e) {
      _lastError = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateDisplayName(String name) async {
    final uid = userId;
    if (uid == null) return;
    await _client.from('profiles').update({'display_name': name}).eq('id', uid);
    await _loadProfile();
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
