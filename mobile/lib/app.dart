import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/core/config/env.dart';
import 'package:nagarik/core/network/supabase_client_provider.dart';
import 'package:nagarik/core/routing/app_router.dart';
import 'package:nagarik/core/startup/splash_screen.dart';
import 'package:nagarik/core/theme/app_theme.dart';
import 'package:nagarik/core/theme/theme_preference.dart';

/// Root application widget.
///
/// Splash/startup (Official Logo & User Profile Photo upgrade): loading
/// `.env` and initializing the Supabase SDK used to happen in `main()`
/// before `runApp` was even called, so the very first frame the person saw
/// was whatever the OS shows before Flutter has drawn anything. `main()`
/// now calls `runApp` immediately with this widget, and [_ready] gates the
/// real `MaterialApp.router` behind [SplashScreen] (the NAGARIK logo, full
/// screen) until both finish — `appRouterProvider` reads
/// `Supabase.instance.client` at build time, so it can only be built once
/// [initSupabase] has actually completed.
class NagarikApp extends ConsumerStatefulWidget {
  const NagarikApp({super.key});

  @override
  ConsumerState<NagarikApp> createState() => _NagarikAppState();
}

class _NagarikAppState extends ConsumerState<NagarikApp> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Env.load();
    await initSupabase();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Deliberately a plain MaterialApp, not the themed one below: the
      // real `AppTheme`/`themePreferenceProvider` are fine to read at this
      // point too, but the splash is intentionally as dependency-free as
      // main() itself was, so a failure in either await still shows the
      // logo rather than a blank screen while it's in flight.
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    final router = ref.watch(appRouterProvider);
    // Settings -> Theme preference (System Default / Light / Dark). Light
    // remains the app's primary/default design — see
    // `theme_preference.dart` for why that's the fallback here too.
    final themePreference = ref.watch(themePreferenceProvider);

    return MaterialApp.router(
      title: 'NAGARIK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themePreference.themeMode,
      routerConfig: router,
    );
  }
}
