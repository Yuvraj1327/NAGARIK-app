import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/l10n/app_localizations.dart';

/// Shared "Logout" confirmation, used by both the Profile screen's ACCOUNT
/// section and the Settings screen — one place for the copy/behavior so
/// they can't drift apart.
///
/// Actually clearing the session happens in `AuthRepository.signOut()`
/// (Supabase's own `signOut()` call, which clears everything this app
/// persists); this dialog only gates *calling* that behind a confirmation,
/// same as any destructive action. Once it fires, the router's auth gate
/// (`core/routing/app_router.dart`) reacts to the resulting auth-state
/// change on its own and returns the app to `/welcome` (NAGARIK Theme
/// upgrade — was `/login`) — no navigation call needed here.
Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.authLogoutTitle),
      content: Text(l10n.authLogoutBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.authCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.authLogout),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await ref.read(authRepositoryProvider).signOut();
  }
}
