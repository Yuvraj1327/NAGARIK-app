import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/app.dart';

/// `.env` loading and Supabase initialization moved into [NagarikApp]
/// itself (Official Logo & User Profile Photo upgrade's Splash/startup
/// requirement) — `runApp` now happens immediately, so the app can show
/// [SplashScreen] (the NAGARIK logo) the instant it launches instead of a
/// blank frame while those two awaits were still pending here.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: NagarikApp()));
}
