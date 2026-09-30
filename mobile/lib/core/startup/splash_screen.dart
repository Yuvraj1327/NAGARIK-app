import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/shared/widgets/logo.dart';

/// Shown immediately at launch, while [NagarikApp] (`lib/app.dart`) loads
/// `.env` and initializes the Supabase SDK — the one moment the app has no
/// theme, no router, and no Supabase client yet, so this deliberately
/// doesn't depend on any of them (no `Theme.of(context)`, no Riverpod
/// providers).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Logo(size: 140),
      ),
    );
  }
}
