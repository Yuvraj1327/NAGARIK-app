import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/core/theme/theme_preference.dart';
import 'package:nagarik/features/auth/presentation/widgets/confirm_logout.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';
import 'package:nagarik/shared/widgets/section_header.dart';
import 'package:nagarik/shared/widgets/settings_list_tile.dart';
import 'package:nagarik/shared/widgets/settings_section.dart';

/// Dedicated Settings screen (Profile -> Settings -> Preferences), separate
/// from the Profile screen itself: Profile is the at-a-glance identity +
/// activity hub, Settings is where account info, the theme preference, and
/// the legal/help/logout rows live together in one place.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final themePreference = ref.watch(themePreferenceProvider);

    return Scaffold(
      appBar: const PrimaryAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionHeader(title: 'Account information'),
          profileAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: LoadingView(),
            ),
            error: (error, stackTrace) => ErrorView.forError(
              error,
              onRetry: () => ref.invalidate(currentUserProfileProvider),
              fallbackMessage: 'Could not load your account information.',
            ),
            data: (profile) => SettingsSection(
              title: null,
              tiles: [
                SettingsListTile(
                  icon: Icons.person_outline,
                  title: profile.displayName,
                  subtitle: profile.email,
                  onTap: () => context.push('/profile/edit'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Theme preference'),
          SettingsSection(
            title: null,
            tiles: [
              for (final preference in AppThemePreference.values)
                SettingsListTile(
                  icon: switch (preference) {
                    AppThemePreference.system => Icons.brightness_auto_outlined,
                    AppThemePreference.light => Icons.light_mode_outlined,
                    AppThemePreference.dark => Icons.dark_mode_outlined,
                  },
                  title: preference.label,
                  trailing: preference == themePreference
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => ref.read(themePreferenceProvider.notifier).setPreference(preference),
                ),
            ],
          ),
          SettingsSection(
            title: null,
            tiles: [
              SettingsListTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () => context.push('/help'),
              ),
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
          const SizedBox(height: AppSpacing.md),
          SettingsSection(
            title: null,
            tiles: [
              SettingsListTile(
                icon: Icons.logout,
                title: 'Logout',
                isDestructive: true,
                onTap: () => confirmAndLogout(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
