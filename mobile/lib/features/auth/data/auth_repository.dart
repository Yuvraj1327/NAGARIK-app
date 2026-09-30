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
  Future<void> updateFullName(String fullName) => _updateMetadata({'full_name': fullName});

  /// Updates the signed-in user's stored profile-photo reference (User
  /// Profile Photo upgrade). Same `user_metadata` mechanism and the same
  /// `refreshSession()` follow-up as [updateFullName] — see that method's
  /// doc comment for why the refresh matters. Called right after a
  /// successful upload/removal against the backend
  /// (`ProfileRepository.uploadAvatar`/`removeAvatar`), never on its own:
  /// this method only ever updates the *reference*, the backend owns the
  /// actual Storage bytes. Pass `null` to clear it (Remove Photo).
  Future<void> updateAvatarPath(String? avatarPath) =>
      _updateMetadata({'avatar_path': avatarPath});

  /// Merges [changes] into the user's existing `user_metadata` and pushes
  /// the result, then refreshes the session so the change is reflected in
  /// the JWT immediately (see [updateFullName]'s doc comment).
  ///
  /// This merges client-side rather than calling `updateUser` with just
  /// `{key: value}` directly, because Supabase Auth's `data` parameter
  /// *replaces* `user_metadata` wholesale rather than merging it — passing
  /// only `{'avatar_path': ...}` would silently wipe out `full_name` (and
  /// vice versa) if it weren't merged in first. A `null` value in
  /// [changes] removes that key entirely rather than storing a literal
  /// null, so `updateAvatarPath(null)` (Remove Photo) actually clears the
  /// field instead of leaving a stale `"avatar_path": null` around.
  Future<void> _updateMetadata(Map<String, dynamic> changes) async {
    final merged = Map<String, dynamic>.from(currentUser?.userMetadata ?? {});
    for (final entry in changes.entries) {
      if (entry.value == null) {
        merged.remove(entry.key);
      } else {
        merged[entry.key] = entry.value;
      }
    }
    await _auth.updateUser(UserAttributes(data: merged));
    await _auth.refreshSession();
  }
}
