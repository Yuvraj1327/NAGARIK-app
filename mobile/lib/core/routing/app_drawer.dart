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
/// Feature Polish upgrade's hybrid navigation structure; regrouped and
/// restyled in the Home/Drawer/Search/My Reports redesign).
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
///
/// [activeRoute] is the tab the drawer was opened from (`/home`, `/search`,
/// `/my-reports`, `/profile`); the matching row is shown as the selected
/// pill. It is passed in by each tab rather than read from the router so the
/// drawer stays usable (and testable) without a `GoRouter` above it.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, this.activeRoute});

  final String? activeRoute;

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
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      child: Column(
        children: [
          _DrawerHeader(
            displayName: profile?.displayName,
            email: profile?.email,
            avatarUrl: profile?.avatarUrl,
            onProfileTap: () => _go(context, '/profile'),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('MAIN'),
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    active: activeRoute == '/home',
                    onTap: () => _go(context, '/home'),
                  ),
                  _DrawerItem(
                    icon: Icons.search_rounded,
                    label: 'Search & Discover',
                    active: activeRoute == '/search',
                    onTap: () => _go(context, '/search'),
                  ),
                  _DrawerItem(
                    icon: Icons.assignment_outlined,
                    label: 'My Reports',
                    active: activeRoute == '/my-reports',
                    onTap: () => _go(context, '/my-reports'),
                  ),
                  _DrawerItem(
                    icon: Icons.bookmark_border_rounded,
                    label: 'Saved Reports',
                    onTap: () => _push(context, '/profile/saved-reports'),
                  ),
                  _DrawerItem(
                    icon: Icons.add_alert_outlined,
                    label: 'Report Issue',
                    onTap: () => _push(context, '/report/create'),
                  ),
                  _DrawerItem(
                    icon: Icons.map_outlined,
                    label: 'Map & Nearby',
                    // Lands on Search already switched to "Near me" and the
                    // Map view — see `search_screen.dart`'s `initialView`
                    // and `app_router.dart`'s `/search` route.
                    onTap: () => _go(context, '/search?nearby=true&view=map'),
                  ),
                  const _SectionLabel('SUPPORT'),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => _push(context, '/settings'),
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    onTap: () => _push(context, '/help'),
                  ),
                  _DrawerItem(
                    icon: Icons.info_outline_rounded,
                    label: 'About NAGARIK',
                    onTap: () => _push(context, '/about'),
                  ),
                  const _SectionLabel('LEGAL'),
                  _DrawerItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => _push(context, '/legal/privacy'),
                  ),
                  _DrawerItem(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => _push(context, '/legal/terms'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                destructive: true,
                // Confirm BEFORE closing the drawer: popping first leaves this
                // context unmounted, so the dialog could never be shown.
                onTap: () async {
                  await confirmAndLogout(context, ref);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.onProfileTap,
  });

  final String? displayName;
  final String? email;
  final String? avatarUrl;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryBright],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 20),
          child: FadeSlideIn(
            offset: const Offset(-0.04, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Official Logo upgrade: the brand mark stays its own row
                // above the account info — the signed-in user's photo below
                // is a separate thing from the app's identity.
                Row(
                  children: [
                    const Logo(size: 34),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'NAGARIK',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Material(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: onProfileTap,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm + 4),
                      child: Row(
                        children: [
                          ProfileAvatar(
                            avatarUrl: avatarUrl,
                            displayName: displayName ?? 'N',
                            radius: 24,
                          ),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName ?? 'NAGARIK',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (email != null)
                                  Text(
                                    email!,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.onPrimary.withOpacity(0.9),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.onPrimary),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final color = destructive ? AppColors.error : (active ? AppColors.primary : baseColor);
    final chevronColor = destructive ? AppColors.error : AppColors.textDisabled;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? AppColors.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: active || destructive ? FontWeight.w700 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: chevronColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
