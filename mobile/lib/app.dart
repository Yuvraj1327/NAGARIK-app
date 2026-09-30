import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/core/routing/app_router.dart';
import 'package:nagarik/core/theme/app_theme.dart';
import 'package:nagarik/core/theme/theme_preference.dart';

/// Root application widget.
class NagarikApp extends ConsumerWidget {
  const NagarikApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
