import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/routing/app_drawer.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/features/auth/presentation/widgets/confirm_logout.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/app_card.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';
import 'package:nagarik/shared/widgets/profile_avatar.dart';
import 'package:nagarik/shared/widgets/settings_list_tile.dart';
import 'package:nagarik/shared/widgets/settings_section.dart';
import 'package:nagarik/shared/widgets/stat_tile.dart';

/// Profile tab. The app-wide auth gate (`core/routing/app_router.dart`)
/// means this screen is never actually reached while signed out — but it
/// still branches on real auth state and keeps the signed-out prompt as a
/// defensive fallback for the brief moment between a sign-out action and
/// the router's redirect landing.
///
/// Signed in: an identity header (avatar placeholder, name, email), a
/// report-count stats strip, then four grouped, navigable sections — MY
/// ACTIVITY, SETTINGS, LEGAL, ACCOUNT — rather than the single long
/// scrolling page this screen used to be. The report list itself moved to
/// its own `MyReportsScreen`, reached via "My Reports" below.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: const PrimaryAppBar(title: 'Profile'),
      drawer: const AppDrawer(),
      body: user == null ? const _SignedOutView() : const _SignedInView(),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle_outlined, size: 64),
            const SizedBox(height: AppSpacing.md),
            Text("You're not logged in", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Log in to submit reports and track their status.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'Log in', onPressed: () => context.push('/login')),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Create account',
              variant: AppButtonVariant.outlined,
              onPressed: () => context.push('/signup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInView extends ConsumerWidget {
  const _SignedInView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => const LoadingView(message: 'Loading your profile…'),
      error: (error, stackTrace) => ErrorView.forError(
        error,
        onRetry: () => ref.invalidate(currentUserProfileProvider),
        fallbackMessage: 'Could not load your profile. Please try again.',
      ),
      data: (profile) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              // Tapping the photo jumps to Edit Profile — the one place
              // that actually offers upload/replace/remove (User Profile
              // Photo upgrade) — rather than duplicating that picker sheet
              // here too.
              GestureDetector(
                onTap: () => context.push('/profile/edit'),
                child: ProfileAvatar(
                  avatarUrl: profile.avatarUrl,
                  displayName: profile.displayName,
                  radius: 32,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName, style: Theme.of(context).textTheme.titleLarge),
                    if (profile.email != null)
                      Text(profile.email!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _ReportStatsStrip(),
          const SettingsSection(
            title: 'My Activity',
            tiles: [
              _MyReportsTile(),
              _SavedReportsTile(),
            ],
          ),
          SettingsSection(
            title: 'Settings',
            tiles: [
              SettingsListTile(
                icon: Icons.edit_outlined,
                title: 'Edit Profile',
                onTap: () => context.push('/profile/edit'),
              ),
              SettingsListTile(
                icon: Icons.tune,
                title: 'Preferences',
                onTap: () => context.push('/settings'),
              ),
              SettingsListTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () => context.push('/help'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Legal',
            tiles: [
              SettingsListTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => context.push('/legal/privacy'),
              ),
              SettingsListTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                onTap: () => context.push('/legal/terms'),
              ),
              SettingsListTile(
                icon: Icons.info_outline,
                title: 'About NAGARIK',
                onTap: () => context.push('/about'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Account',
            tiles: [
              SettingsListTile(
                icon: Icons.logout,
                title: 'Logout',
                isDestructive: true,
                onTap: () => confirmAndLogout(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Total / Resolved / In Review / Submitted counters, backed by
/// `GET /reports/stats`. A dedicated widget so its own loading/error state
/// doesn't block the rest of the Profile screen (the identity header and
/// section list below render immediately regardless of whether stats have
/// loaded yet).
class _ReportStatsStrip extends ConsumerWidget {
  const _ReportStatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(reportStatsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: statsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: LoadingView(),
          ),
          error: (error, stackTrace) => ErrorView.forError(
            error,
            onRetry: () => ref.invalidate(reportStatsProvider),
            fallbackMessage: 'Could not load your report stats.',
          ),
          data: (stats) => Row(
            children: [
              Expanded(child: StatTile(value: stats.total, label: 'Total\nReports')),
              const _StatDivider(),
              Expanded(
                child: StatTile(
                  value: stats.resolved,
                  label: 'Resolved',
                  color: AppColors.statusResolved,
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: StatTile(
                  value: stats.inReview,
                  label: 'In Review',
                  color: AppColors.statusInReview,
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: StatTile(
                  value: stats.submitted,
                  label: 'Submitted',
                  color: AppColors.statusSubmitted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 40, child: VerticalDivider(width: AppSpacing.md));
  }
}

class _MyReportsTile extends StatelessWidget {
  const _MyReportsTile();

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      icon: Icons.history_outlined,
      title: 'My Reports',
      // My Reports is now also a bottom-nav tab (`/my-reports`) — this tile
      // just switches to that tab rather than pushing a second screen for
      // the same feature, same as Home's category shortcuts already do for
      // Search (`context.go` across shell branches).
      onTap: () => context.go('/my-reports'),
    );
  }
}

class _SavedReportsTile extends StatelessWidget {
  const _SavedReportsTile();

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      icon: Icons.bookmark_border,
      title: 'Saved Reports',
      onTap: () => context.push('/profile/saved-reports'),
    );
  }
}
