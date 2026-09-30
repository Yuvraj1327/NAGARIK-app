import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase Auth. This is the ONLY place in the app
/// that calls `Supabase.instance.client.auth` directly — everything else
/// reads auth state via the Riverpod providers in
/// `presentation/providers/auth_providers.dart`.
///
/// Session persistence and token refresh are handled automatically by the
/// `supabase_flutter` SDK once `Supabase.initialize()` has run (see
/// `core/network/supabase_client_provider.dart`) — nothing extra is needed
/// here for that.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;

  User? get currentUser => _auth.currentUser;

  /// Fires on sign-in, sign-out, token refresh, and the restored session
  /// on app startup (`AuthChangeEvent.initialSession`).
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _auth.signUp(
      email: email,
      password: password,
      // Stored in the JWT's `user_metadata` claim, which is exactly what
      // the backend reads for `full_name` in GET /users/me — no separate
      // profiles table needed.
      data: {'full_name': fullName},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithPassword(email: email, password: password);
  }

  /// Clears the local session and revokes it server-side. `signOut()` on
  /// Supabase's own client already clears everything this app persists
  /// (the SDK's own local storage) — there's no separate app-level cache
  /// of the session to clear on top of that, so this is a complete logout
  /// on its own; the router's auth gate then bounces the app back to
  /// `/login` automatically (see `core/routing/app_router.dart`).
  Future<void> signOut() => _auth.signOut();

  /// Updates the signed-in user's display name (Profile -> Edit Profile).
  ///
  /// Same storage as `signUp()`'s `data: {'full_name': ...}` — Supabase
  /// Auth's `user_metadata`, not a separate `profiles` table (there isn't
  /// one; see `docs/ARCHITECTURE.md`). `updateUser()` alone updates that
  /// metadata but does NOT guarantee the *current* access token's embedded
  /// `user_metadata` claim reflects it immediately — GoTrue only re-mints
  /// the JWT on its next natural refresh, which could be up to an hour
  /// away. Since the backend's `GET /users/me` (`app/core/security.py`)
  /// reads `full_name` straight out of the JWT with no database round
  /// trip, an explicit `refreshSession()` right after is what makes the
  /// edit show up immediately instead of eventually.
  Future<void> updateFullName(String fullName) async {
    await _auth.updateUser(UserAttributes(data: {'full_name': fullName}));
    await _auth.refreshSession();
  }
}
