/// Onboarding redesign: the language choice offered on Step 1 of the
/// first-run onboarding flow (`onboarding_screen.dart`).
///
/// This is a UI-level preference only — selecting one here does not
/// translate the rest of the app. Full in-app localization (every screen's
/// strings in Hindi/Marathi) is a separate, much larger effort outside
/// this step's scope (and outside this project's standing scope list; see
/// `docs/ARCHITECTURE.md`'s write-up for this step for the full
/// reasoning). The chosen value is saved locally via `OnboardingService`
/// so it's available for that future work, and shown back on the
/// Preferences step (Step 7) so the person can change their mind.
enum OnboardingLanguage {
  english,
  hindi,
  marathi;

  String get label => switch (this) {
        OnboardingLanguage.english => 'English',
        OnboardingLanguage.hindi => 'हिन्दी',
        OnboardingLanguage.marathi => 'मराठी',
      };
}
