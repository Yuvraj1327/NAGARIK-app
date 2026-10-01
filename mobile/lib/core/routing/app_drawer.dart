import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/auth/presentation/widgets/confirm_logout.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/logo.dart';
import 'package:nagarik/shared/widgets/profile_avatar.dart';

/// The app's full feature menu (Report Sharing, Saved Reports & Final
/// Feature Polish upgrade's hybrid navigation structure).
///
/// Added to the bottom-nav tabs' own `Scaffold`s — Home, Search, My
/// Reports, Profile (see each screen's `drawer:` parameter) — rather than
/// to the outer shell scaffold (`ScaffoldWithNavBar`), because that's where
/// each tab's own `AppBar` actually lives; a `Scaffold` only auto-shows the
/// hamburger icon on an `AppBar` that's its own direct child. Every
/// destination here reuses an existing route (nothing here is a second
/// screen built just for the drawer — see `app_router.dart`), so the
/// bottom bar and the drawer are two entry points into the same routes,
/// never two copies of the same feature.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _go(BuildContext context, String location) {
    Navigator.of(context).pop();
    context.go(location);
  }

  void _push(BuildContext context, String location) {
    Navigator.of(context).pop();
    context.push(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.asData?.value;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Official Logo upgrade: the brand mark at the top of the app's
          // full feature menu. Kept as its own row above the account
          // info — not merged into `currentAccountPicture` below, which is
          // the signed-in *user's* photo (User Profile Photo upgrade), a
          // separate thing from the app's own identity.
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: FadeSlideIn(
              offset: const Offset(-0.04, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Logo(size: 32),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'NAGARIK',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      ProfileAvatar(
                        avatarUrl: profile?.avatarUrl,
                        displayName: profile?.displayName ?? 'N',
                        radius: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              profile?.displayName ?? 'NAGARIK',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (profile?.email != null)
                              Text(
                                profile!.email!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.onPrimary,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () => _go(context, '/home'),
          ),
          ListTile(
            leading: const Icon(Icons.search_outlined),
            title: const Text('Search / Discover'),
            onTap: () => _go(context, '/search'),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('My Reports'),
            onTap: () => _go(context, '/my-reports'),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Saved Reports'),
            onTap: () => _push(context, '/profile/saved-reports'),
          ),
          ListTile(
            leading: const Icon(Icons.add_alert_outlined),
            title: const Text('Report Issue'),
            onTap: () => _push(context, '/report/create'),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Map / Nearby'),
            // Lands on Search already switched to "Near me" and the Map
            // view — see `search_screen.dart`'s `initialView` and
            // `app_router.dart`'s `/search` route.
            onTap: () => _go(context, '/search?nearby=true&view=map'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () => _push(context, '/settings'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () => _push(context, '/help'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _push(context, '/legal/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms & Conditions'),
            onTap: () => _push(context, '/legal/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About NAGARIK'),
            onTap: () => _push(context, '/about'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Logout', style: TextStyle(color: AppColors.error)),
            onTap: () {
              Navigator.of(context).pop();
              confirmAndLogout(context, ref);
            },
          ),
        ],
      ),
    );
  }
}
