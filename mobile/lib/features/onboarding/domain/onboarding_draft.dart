import 'package:nagarik/features/onboarding/domain/age_group.dart';
import 'package:nagarik/features/onboarding/domain/onboarding_language.dart';

/// In-progress state collected across the onboarding flow's optional
/// steps, held by `OnboardingScreen` — mirrors `ReportDraft`'s role for
/// report creation (same "plain mutable holder" pattern).
///
/// Nothing here is persisted on its own. A step's Continue/Finish action
/// explicitly reads the relevant field and saves it through
/// `OnboardingService`; tapping that same step's Skip advances without
/// ever reading from (or persisting) this object, so a value the person
/// started entering but then skipped past is simply discarded.
class OnboardingDraft {
  OnboardingLanguage? language;
  String phoneNumber = '';
  AgeGroup? ageGroup;

  /// Both default to opted-in (`true`) — Step 5 (Data & Privacy) shows
  /// them as switches the person can turn off; Step 6 (Permissions) only
  /// bothers triggering the real OS prompt for a permission that's still
  /// `true` here. Never required: Skip on Step 5 just leaves these at
  /// their defaults.
  bool locationPreviewEnabled = true;
  bool cameraPreviewEnabled = true;
}
