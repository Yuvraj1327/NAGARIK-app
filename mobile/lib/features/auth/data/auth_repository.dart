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

  Future<void> signOut() => _auth.signOut();
}
