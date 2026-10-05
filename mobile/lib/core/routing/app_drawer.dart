import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/auth/presentation/widgets/confirm_logout.dart';
import 'package:nagarik/features/profile/domain/user_profile.dart';
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

  /// The tab route the drawer was opened from, used to highlight its entry.
  /// `null` when there's no router above (widget tests) — nothing is then
  /// highlighted rather than throwing.
  Uri? _currentUri(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    return router?.routeInformationProvider.value.uri;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).asData?.value;
    final uri = _currentUri(context);
    final path = uri?.path;
    final isMapView = uri?.queryParameters['view'] == 'map' &&
        uri?.queryParameters['nearby'] == 'true';

    bool onPath(String route) => path == route;

    return Drawer(
      child: Column(
        children: [
          _DrawerHeader(profile: profile),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
              children: [
                const _DrawerSectionLabel('Main'),
                _DrawerItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  selected: onPath('/home'),
                  onTap: () => _go(context, '/home'),
                ),
                _DrawerItem(
                  icon: Icons.search_outlined,
                  label: 'Search / Discover',
                  selected: onPath('/search') && !isMapView,
                  onTap: () => _go(context, '/search'),
                ),
                _DrawerItem(
                  icon: Icons.assignment_outlined,
                  label: 'My Reports',
                  selected: onPath('/my-reports'),
                  onTap: () => _go(context, '/my-reports'),
                ),
                _DrawerItem(
                  icon: Icons.bookmark_border,
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
                  label: 'Map / Nearby',
                  // Lands on Search already switched to "Near me" and the
                  // Map view — see `search_screen.dart`'s `initialView` and
                  // `app_router.dart`'s `/search` route.
                  selected: onPath('/search') && isMapView,
                  onTap: () => _go(context, '/search?nearby=true&view=map'),
                ),
                const _DrawerSectionLabel('Support'),
                _DrawerItem(
                  icon: Icons.help_outline,
                  label: 'Help & Support',
                  onTap: () => _push(context, '/help'),
                ),
                _DrawerItem(
                  icon: Icons.info_outline,
                  label: 'About NAGARIK',
                  onTap: () => _push(context, '/about'),
                ),
                const _DrawerSectionLabel('Legal'),
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
                const _DrawerSectionLabel('Account'),
                _DrawerItem(
                  icon: Icons.person_outline,
                  label: 'My Profile',
                  selected: onPath('/profile'),
                  onTap: () => _go(context, '/profile'),
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => _push(context, '/settings'),
                ),
              ],
            ),
          ),
          // Logout sits outside the scrolling list so it's always reachable
          // and visually separate from the navigation entries above.
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: _DrawerItem(
                icon: Icons.logout,
                label: 'Logout',
                color: AppColors.error,
                onTap: () {
                  Navigator.of(context).pop();
                  confirmAndLogout(context, ref);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand-gradient header: the app mark on top (Official Logo upgrade —
/// its own row, separate from the signed-in *user's* photo below, which is
/// the User Profile Photo upgrade's avatar), then avatar, name, and a
/// smaller, subtler email line.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final name = profile?.displayName ?? 'NAGARIK';
    // `displayName` falls back to the email for users with no full name;
    // don't print the same address twice in that case.
    final email = profile?.email;
    final showEmail = email != null && email != name;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.accentTeal],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: FadeSlideIn(
            offset: const Offset(-0.04, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Logo(size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'NAGARIK',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.onPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: ProfileAvatar(
                        avatarUrl: profile?.avatarUrl,
                        displayName: name,
                        radius: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: textTheme.titleMedium?.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showEmail)
                            Text(
                              email,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.onPrimary.withValues(alpha: 0.78),
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
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
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm + 4, AppSpacing.md, AppSpacing.sm, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? AppColors.darkTextDisabled : AppColors.textDisabled,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

/// One compact drawer row. [selected] gives it the tinted rounded pill
/// highlight; [color] overrides the icon/label color (Logout's red).
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = isDark ? AppColors.primary.withValues(alpha: 0.22) : AppColors.primaryLight;
    final activeColor = isDark ? AppColors.primaryBright : AppColors.primary;
    final foreground = color ?? (selected ? activeColor : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        minLeadingWidth: 24,
        horizontalTitleGap: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        selected: selected,
        selectedColor: activeColor,
        selectedTileColor: highlight,
        leading: Icon(icon, size: 22, color: foreground),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: foreground,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
