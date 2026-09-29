import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nagarik/features/auth/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

/// Emits on every auth state change (sign in, sign out, token refresh, and
/// the restored session on app startup). The router
/// (`core/routing/app_router.dart`) watches this via `GoRouterRefreshStream`
/// to redirect correctly, and the profile screen watches
/// [currentUserProvider] (below) to decide which view to show.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// The currently signed-in Supabase user, or null if signed out.
///
/// Derived from [authStateChangesProvider] so it updates reactively on
/// every auth change; falls back to reading the session directly for the
/// brief moment before that stream has emitted its first event (Supabase
/// is already initialized with any persisted session by the time the app
/// starts, so this fallback is rarely, if ever, actually exercised).
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.maybeWhen(
    data: (state) => state.session?.user,
    orElse: () => ref.read(authRepositoryProvider).currentUser,
  );
});
