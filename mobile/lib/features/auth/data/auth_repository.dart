import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nagarik/core/config/env.dart';

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

  // NAGARIK Theme upgrade: one `GoogleSignIn` instance for the app's
  // lifetime, configured straight from `.env` since this project has no
  // native android/ios folders yet for the package to read platform config
  // files from (see `Env.googleWebClientId`/`Env.googleIosClientId`'s doc
  // comments). Both are `null`-safe to pass when unset — the package then
  // falls back to its own platform defaults, which will simply fail with a
  // clear error if Google Sign-In truly hasn't been configured, rather
  // than crashing anything else in the app.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: Env.googleWebClientId,
    clientId: Env.googleIosClientId,
  );

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

  /// "Continue with Google" (NAGARIK Theme upgrade): opens the platform's
  /// own native account picker (via `google_sign_in`) rather than an
  /// in-app browser/webview, then exchanges the account's Google ID token
  /// for a real Supabase session via `signInWithIdToken` — this is the
  /// flow Supabase's own docs recommend for native mobile apps. Once this
  /// resolves, the router's `refreshListenable` picks up the new session
  /// and leaves `/welcome` automatically, the same way `signIn`/`signUp`
  /// already do — no manual navigation needed here.
  ///
  /// Throws a plain [StateError] (not an [AuthException]) for the two
  /// routine, expected non-success paths: the person dismissed the account
  /// picker without choosing an account, or Google Sign-In hasn't been
  /// configured yet for this project (see `Env.googleWebClientId`'s doc
  /// comment and `mobile/README.md`'s "Google sign-in" section) — the
  /// welcome screen tells these apart by message to decide whether to show
  /// an error at all.
  Future<AuthResponse> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw StateError('cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError(
        'Google sign-in is not fully configured yet. Set '
        'GOOGLE_WEB_CLIENT_ID (and GOOGLE_IOS_CLIENT_ID on iOS) in .env and '
        'enable the Google provider in the Supabase dashboard.',
      );
    }

    return _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
  }

  /// Clears the local session and revokes it server-side. `signOut()` on
  /// Supabase's own client already clears everything this app persists
  /// (the SDK's own local storage) — there's no separate app-level cache
  /// of the session to clear on top of that, so this is a complete logout
  /// on its own; the router's auth gate then bounces the app back to
  /// `/welcome` automatically (see `core/routing/app_router.dart`).
  ///
  /// Also best-effort signs out of the cached Google account (NAGARIK
  /// Theme upgrade), so a future "Continue with Google" shows the account
  /// picker again instead of silently reusing whichever account was used
  /// last. Swallowed on failure — this is a UX nicety, not something that
  /// should ever block an actual logout.
  Future<void> signOut() async {
    await _auth.signOut();
    unawaited(_googleSignIn.signOut().catchError((_) {}));
  }

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
