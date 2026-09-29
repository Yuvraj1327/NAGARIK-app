import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nagarik/core/config/env.dart';

/// Initializes the Supabase SDK. Call once, before `runApp`.
///
/// This client is used ONLY for Supabase Auth (signup/login/session/
/// logout — implemented in Step 3). It is deliberately not used to read or
/// write Postgres tables or Storage buckets directly from Flutter; those
/// operations go through the FastAPI backend (see ApiClient and
/// docs/ARCHITECTURE.md) so the backend can enforce business rules and
/// keep Storage/DB access behind a single, auditable surface.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
}

/// Riverpod provider for the Supabase auth client specifically, so feature
/// code depends on this narrow surface rather than the whole Supabase SDK.
final supabaseAuthProvider = Provider<GoTrueClient>(
  (ref) => Supabase.instance.client.auth,
);
