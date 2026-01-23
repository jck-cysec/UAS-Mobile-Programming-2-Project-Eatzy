import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Clear in-memory caches when logging out
import '/data/services/cart_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class SessionProvider extends ChangeNotifier {
  User? _user;
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;

  Map<String, dynamic>? _userProfile;
  bool _profileLoaded = false;

  static const String _lastActivityKey = 'last_activity_timestamp';
  static const int _sessionExpiryDays = 30;

  // Cached profile keys (used as a safe fallback when network is unavailable)
  static const String _cachedFullNameKey = 'cached_full_name';
  static const String _cachedRoleKey = 'cached_role';

  SessionProvider() {
    _initializeAuth();
  }

  /// Test-only constructor that avoids network/auth initialization.
  /// Use in widget/unit tests to provide deterministic session state.
  @visibleForTesting
  SessionProvider.test({User? user, Map<String, dynamic>? profile, bool loggedIn = false}) {
    _user = user;
    _userProfile = profile;
    _profileLoaded = profile != null;
    _status = loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    _testForceLoggedIn = loggedIn;
  }

  /* =======================
   * GETTERS
   * ======================= */

  User? get user => _user;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get userProfile => _userProfile;

  // Test hook: allow tests to force-authenticated state without a real User.
  bool _testForceLoggedIn = false;

  bool get isLoggedIn =>
      _testForceLoggedIn || (_user != null && _status == AuthStatus.authenticated);

  bool get isLoading => _status == AuthStatus.loading;
  bool get hasError => _status == AuthStatus.error;

  bool get isProfileLoaded => _profileLoaded;

  String get role => _userProfile?['role'] ?? 'user';
  bool get isAdmin => role == 'admin';
  bool get isUser => role == 'user';

  String get displayName {
    // Prefer canonical full_name from users table
    final fnFromProfile = _userProfile != null ? (_userProfile!['full_name'] as String?) : null;
    if (fnFromProfile != null && fnFromProfile.trim().isNotEmpty) return fnFromProfile.trim();

    // Fallback to Supabase Auth user metadata (some providers store name there)
    try {
      final meta = _user?.userMetadata;
      final fnMeta = (meta is Map) ? (meta?['full_name'] ?? meta?['fullName'] ?? meta!['name']) : null;
      if (fnMeta is String && fnMeta.trim().isNotEmpty) return fnMeta.trim();
    } catch (_) {}

    // Final fallback: local part of email or generic label
    return _user?.email?.split('@').first ?? 'User';
  }

  /* =======================
   * INIT AUTH
   * ======================= */

  Future<void> _initializeAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      _user = Supabase.instance.client.auth.currentUser;

      if (_user == null) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final expired = await _checkSessionExpiry();
      if (expired) {
        await _forceLogout(reason: 'Session expired');
        return;
      }

      final exists = await _checkUserExists();
      if (!exists) {
        await _forceLogout(reason: 'User not found');
        return;
      }

      await _updateLastActivity();

      _status = AuthStatus.authenticated;
      await ensureProfileLoaded();

      Supabase.instance.client.auth.onAuthStateChange.listen(
        _handleAuthStateChange,
        onError: _handleAuthError,
      );

      notifyListeners();
    } catch (e) {
      _handleAuthError(e);
    }
  }

  /* =======================
   * PROFILE
   * ======================= */

  Future<void> ensureProfileLoaded() async {
    if (_user == null) return;

    if (_userProfile != null && _profileLoaded) return;

    await _fetchUserProfile();
  }

  /// Force-reload the user's profile from the server and notify listeners.
  Future<void> reloadProfile() async {
    if (_user == null) return;
    await _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    _profileLoaded = false;
    notifyListeners();

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', _user!.id)
          .single();

      _userProfile = response;
      _profileLoaded = true;

      // Persist a lightweight cached profile so UI can show displayName on network hiccups
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_userProfile != null) {
          final fn = _userProfile!['full_name'] as String?;
          final role = _userProfile!['role'] as String?;
          if (fn != null) await prefs.setString(_cachedFullNameKey, fn);
          if (role != null) await prefs.setString(_cachedRoleKey, role);
        }
      } catch (_) {}

      debugPrint(
        '👤 Profile loaded | email=${_user?.email} | role=${_userProfile?['role']}',
      );
    } catch (e) {
      debugPrint('❌ Fetch profile failed: $e');
      // If network fails, attempt to load cached profile instead of immediately logging out
      final loaded = await _loadCachedProfile();
      if (!loaded) {
        // If no cached profile, it's likely the account was removed or unrecoverable — force logout
        await _forceLogout(reason: 'Profile not found');
      }
    }

    notifyListeners();
  }

  /* =======================
   * CACHED PROFILE HELPERS
   * ======================= */

  Future<bool> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fn = prefs.getString(_cachedFullNameKey);
      final role = prefs.getString(_cachedRoleKey);
      if (fn == null && role == null) return false;
      _userProfile = {
        if (fn != null) 'full_name': fn,
        if (role != null) 'role': role,
      };
      _profileLoaded = true;
      debugPrint('👤 Loaded cached profile | full_name=$fn | role=$role');
      return true;
    } catch (_) {
      return false;
    }
  }


  /* =======================
   * AUTH STATE CHANGE
   * ======================= */

  Future<void> _handleAuthStateChange(AuthState data) async {
    _user = data.session?.user;

    switch (data.event) {
      case AuthChangeEvent.signedIn:
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        await _updateLastActivity();
        await ensureProfileLoaded();
        break;

      case AuthChangeEvent.signedOut:
        await _clearSession();
        break;

      case AuthChangeEvent.userDeleted:
        await _forceLogout(reason: 'User deleted');
        break;

      case AuthChangeEvent.tokenRefreshed:
        await _updateLastActivity();
        break;

      default:
        break;
    }

    notifyListeners();
  }

  void _handleAuthError(dynamic error) {
    _status = AuthStatus.error;
    _errorMessage = error.toString();
    debugPrint('❌ Auth error: $error');
    notifyListeners();
  }

  /* =======================
   * SESSION VALIDATION
   * ======================= */

  Future<bool> validateSession() async {
    if (_user == null) return false;

    final expired = await _checkSessionExpiry();
    if (expired) {
      await _forceLogout(reason: 'Session expired');
      return false;
    }

    final exists = await _checkUserExists();
    if (!exists) {
      await _forceLogout(reason: 'User deleted');
      return false;
    }

    await _updateLastActivity();
    return true;
  }

  Future<bool> refreshSession() async {
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      final response =
          await Supabase.instance.client.auth.refreshSession();

      if (response.session == null) {
        throw Exception('Refresh session failed');
      }

      _user = response.session!.user;
      _status = AuthStatus.authenticated;

      await ensureProfileLoaded();
      notifyListeners();
      return true;
    } catch (e) {
      _handleAuthError(e);
      return false;
    }
  }

  /* =======================
   * LOGOUT
   * ======================= */

  Future<void> _forceLogout({String? reason}) async {
    await Supabase.instance.client.auth.signOut();
    await _clearSession();
    _errorMessage = reason;
    notifyListeners();
  }

  Future<bool> logout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      await _clearSession();
      notifyListeners();
      return true;
    } catch (e) {
      _handleAuthError(e);
      return false;
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastActivityKey);
    await prefs.remove(_cachedFullNameKey);
    await prefs.remove(_cachedRoleKey);

    _user = null;
    _userProfile = null;
    _profileLoaded = false;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;

    // clear in-memory caches to avoid leaving residual user/admin data
    try {
      CartService.instance.clear();
    } catch (_) {}

    // NOTE: Do NOT clear MenuService cache on logout. Admin menu must remain
    // available even after the admin user logs out (per product requirements).
    // This prevents the admin view from appearing empty when session changes.
    // try { MenuService.instance.menus.value = []; } catch (_) {}
  }

  /* =======================
   * HELPERS
   * ======================= */

  Future<bool> _checkUserExists() async {
    try {
      final res = await Supabase.instance.client.auth.getUser();
      return res.user != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkSessionExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_lastActivityKey);

    if (last == null) {
      await _updateLastActivity();
      return false;
    }

    final lastTime = DateTime.parse(last);
    final days = DateTime.now().difference(lastTime).inDays;
    return days >= _sessionExpiryDays;
  }

  Future<void> _updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastActivityKey,
      DateTime.now().toIso8601String(),
    );
  }
}
