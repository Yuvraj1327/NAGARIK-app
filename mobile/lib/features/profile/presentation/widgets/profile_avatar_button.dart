import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/shared/widgets/profile_avatar.dart';

/// The small circular avatar in the top-right of the main tabs' headers —
/// the signed-in user's real photo/initial, opening the Profile tab.
class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Semantics(
        button: true,
        label: 'Open profile',
        child: GestureDetector(
          onTap: () => context.go('/profile'),
          child: ProfileAvatar(
            avatarUrl: profile?.avatarUrl,
            displayName: profile?.displayName ?? 'N',
            radius: 18,
          ),
        ),
      ),
    );
  }
}
