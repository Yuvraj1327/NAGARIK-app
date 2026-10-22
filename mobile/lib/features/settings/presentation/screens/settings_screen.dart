import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/localization/language_preference.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/core/theme/theme_preference.dart';
import 'package:nagarik/features/auth/presentation/widgets/confirm_logout.dart';
import 'package:nagarik/features/onboarding/domain/onboarding_language.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';
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
    final language = ref.watch(languageProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: PrimaryAppBar(title: l10n.setTitle),
      body: ResponsiveCenter(
        child: FadeSlideIn(
          child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SectionHeader(title: l10n.setAccountInformation),
          profileAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: LoadingView(),
            ),
            error: (error, stackTrace) => ErrorView.forError(
              error,
              onRetry: () => ref.invalidate(currentUserProfileProvider),
              fallbackMessage: l10n.setAccountLoadError,
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
                if (profile.phoneOrNull != null)
                  SettingsListTile(
                    icon: Icons.phone_outlined,
                    title: profile.phoneOrNull!,
                    subtitle: l10n.setMobileNumber,
                    onTap: () => context.push('/profile/edit'),
                  ),
              ],
            ),
          ),
          SectionHeader(title: l10n.setThemePreference),
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
                  title: preference.localizedLabel(l10n),
                  trailing: preference == themePreference
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => ref.read(themePreferenceProvider.notifier).setPreference(preference),
                ),
            ],
          ),
          SectionHeader(title: l10n.setLanguage),
          SettingsSection(
            title: null,
            tiles: [
              for (final option in OnboardingLanguage.values)
                SettingsListTile(
                  icon: Icons.language,
                  title: option.label,
                  trailing: option == language
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => ref.read(languageProvider.notifier).setLanguage(option),
                ),
            ],
          ),
          SettingsSection(
            title: null,
            tiles: [
              SettingsListTile(
                icon: Icons.help_outline,
                title: l10n.setHelpSupport,
                onTap: () => context.push('/help'),
              ),
              SettingsListTile(
                icon: Icons.privacy_tip_outlined,
                title: l10n.legalPrivacyPolicy,
                onTap: () => context.push('/legal/privacy'),
              ),
              SettingsListTile(
                icon: Icons.description_outlined,
                title: l10n.legalTermsConditions,
                onTap: () => context.push('/legal/terms'),
              ),
              SettingsListTile(
                icon: Icons.info_outline,
                title: l10n.legalAboutNagarik,
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
                title: l10n.commonLogout,
                isDestructive: true,
                onTap: () => confirmAndLogout(context, ref),
              ),
            ],
          ),
        ],
          ),
        ),
      ),
    );
  }
}
