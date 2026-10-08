import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/core/theme/theme_preference.dart';
import 'package:nagarik/features/onboarding/domain/age_group.dart';
import 'package:nagarik/features/onboarding/domain/onboarding_draft.dart';
import 'package:nagarik/features/onboarding/domain/onboarding_language.dart';
import 'package:nagarik/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_step_indicator.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/animations/pressable_scale.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/app_card.dart';
import 'package:nagarik/shared/widgets/app_text_field.dart';
import 'package:nagarik/shared/widgets/logo.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';

/// Onboarding redesign: the app's first-run flow — a Welcome page followed
/// by seven fully optional steps (Language, About, Mobile Number, Age,
/// Data & Privacy, Permissions, Preferences) — shown once, before the
/// existing Auth Welcome screen (`/welcome`, "Continue with Email" /
/// "Continue with Google"), which this flow hands off to unchanged. A
/// reference app's onboarding was used only to gauge structure/pacing/
/// polish (one idea per screen, a progress indicator, a visible Skip
/// everywhere); its own branding, colors, phone-OTP login, and unrelated
/// features (SOS, emergency contacts, live location sharing) were
/// deliberately not reused — every screen here is built from NAGARIK's
/// own palette, copy, and existing components.
///
/// Every one of the 7 steps can be skipped, and a step's own Skip only
/// ever skips *that* step — see `core/routing/app_router.dart` and
/// `docs/ARCHITECTURE.md`'s write-up for this step for the full
/// before/after and the auth-gate wiring. Only the Welcome page's
/// top-right "Skip" leaves the whole flow in one tap.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// 0 = the Welcome page; 1..7 = the seven numbered steps, in order.
  static const int _lastStep = 7;

  int _currentStep = 0;
  final OnboardingDraft _draft = OnboardingDraft();

  Future<void> _finish() async {
    await ref.read(onboardingServiceProvider).markFinished();
    if (!mounted) return;
    // Replaces the whole stack rather than pushing — there's nothing to
    // come "back" to from the real auth screens once onboarding is done,
    // exactly like a fresh, onboarding-skipped cold start would land here.
    context.go('/welcome');
  }

  void _onGetStarted() => setState(() => _currentStep = 1);

  /// Guards [_onContinue]/[_onSkipStep]: both `await` before advancing, so
  /// a quick double-tap would otherwise advance two steps (or call
  /// [_finish] twice).
  bool _isBusy = false;

  void _onBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  /// Jumps straight to a given step — used by Step 7's "Change" link back
  /// to the language choice on Step 1, the same "edit an earlier step"
  /// pattern `CreateReportScreen`'s Review step uses.
  void _editStep(int step) => setState(() => _currentStep = step);

  Future<void> _onContinue() async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      await _saveCurrentStep();
      await _advance();
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _saveCurrentStep() async {
    // An if-chain rather than a `switch` on purpose — same reasoning as
    // `CreateReportScreen._onContinue`: only one of these can ever apply
    // per call (`_currentStep` is a single value), and a standard Dart
    // `switch` statement doesn't allow a non-empty case to fall through to
    // the next one without an explicit `continue <label>;` anyway.
    final onboarding = ref.read(onboardingServiceProvider);
    if (_currentStep == 1) {
      final language = _draft.language;
      if (language != null) await onboarding.setLanguage(language);
    }
    if (_currentStep == 3) {
      final phone = _draft.phoneNumber.trim();
      if (phone.isNotEmpty) await onboarding.setPendingPhoneNumber(phone);
    }
    if (_currentStep == 4) {
      final ageGroup = _draft.ageGroup;
      if (ageGroup != null) await onboarding.setAgeGroup(ageGroup);
    }
  }

  /// Skip only ever discards whatever is sitting in [_draft] for the step
  /// being left (see that class's doc comment) — it never calls into
  /// [OnboardingService], it just moves on.
  Future<void> _onSkipStep() async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      await _advance();
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _advance() async {
    if (_currentStep < _lastStep) {
      setState(() => _currentStep += 1);
    } else {
      await _finish();
    }
  }

  Widget _buildStepBody() {
    switch (_currentStep) {
      case 1:
        return _OnboardingStepScaffold(
          key: const ValueKey(1),
          title: 'Choose your language',
          subtitle: 'You can change this anytime from Preferences.',
          child: _LanguageStep(
            selected: _draft.language,
            onSelected: (language) => setState(() => _draft.language = language),
          ),
        );
      case 2:
        return const _OnboardingStepScaffold(
          key: ValueKey(2),
          title: 'About NAGARIK',
          subtitle: 'A quick look at what this app is for.',
          child: _AboutStep(),
        );
      case 3:
        return _OnboardingStepScaffold(
          key: const ValueKey(3),
          title: 'Stay reachable (optional)',
          subtitle: "We'll only ever use this if a reviewer needs to reach you about a report.",
          child: _MobileNumberStep(draft: _draft),
        );
      case 4:
        return _OnboardingStepScaffold(
          key: const ValueKey(4),
          title: 'Are you 18 or older?',
          subtitle: 'Just so we can tailor a couple of things — entirely optional.',
          child: _AgeStep(
            selected: _draft.ageGroup,
            onSelected: (ageGroup) => setState(() => _draft.ageGroup = ageGroup),
          ),
        );
      case 5:
        return _OnboardingStepScaffold(
          key: const ValueKey(5),
          title: 'Data & privacy',
          subtitle: 'Choose what NAGARIK is allowed to ask for next.',
          child: _PrivacyStep(draft: _draft),
        );
      case 6:
        return _OnboardingStepScaffold(
          key: const ValueKey(6),
          title: 'Permissions',
          subtitle: 'Only what report creation actually uses — nothing runs in the background.',
          child: _PermissionsStep(draft: _draft),
        );
      case 7:
      default:
        return _OnboardingStepScaffold(
          key: const ValueKey(7),
          title: 'Preferences',
          subtitle: "Last step — you're almost in.",
          child: _PreferencesStep(
            language: _draft.language,
            onEditLanguage: () => _editStep(1),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0) {
      return _WelcomePage(onGetStarted: _onGetStarted, onSkip: _finish);
    }

    final isLastStep = _currentStep == _lastStep;

    // The system/gesture back button steps back through onboarding instead
    // of closing the app from the middle of the flow.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
                child: Row(
                  children: [
                    IconButton(onPressed: _onBack, icon: const Icon(Icons.arrow_back)),
                    Expanded(
                      child: ReportStepIndicator(stepCount: _lastStep, currentStep: _currentStep - 1),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ResponsiveCenter(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.03),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _buildStepBody(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onSkipStep,
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: isLastStep ? 'Finish' : 'Continue',
                        onPressed: _onContinue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page 0 — an original design built around NAGARIK's own palette and the
/// existing `auth_hero.jpg` asset, deliberately framed as a rounded card
/// rather than full-bleed so it reads as a distinct screen from the
/// existing `AuthWelcomeScreen` (`/welcome`) it hands off to, even though
/// both share the same brand tagline.
class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onGetStarted, required this.onSkip});

  final VoidCallback onGetStarted;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveCenter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              children: [
                FadeSlideIn(
                  offset: const Offset(0, -0.3),
                  child: Row(
                    children: [
                      const Logo(size: 28),
                      const SizedBox(width: AppSpacing.xs),
                      const Text(
                        'NAGARIK',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      TextButton(onPressed: onSkip, child: const Text('Skip')),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.sm),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 80),
                          duration: const Duration(milliseconds: 560),
                          beginScale: 1.06,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: Image.asset(
                              'assets/images/auth_hero.jpg',
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 160),
                          child: const Text(
                            'A CIVIC GOOD INITIATIVE',
                            style: TextStyle(
                              color: AppColors.accentTeal,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 190),
                          child: Text(
                            'See it. Report it. Get it fixed.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 220),
                          child: Text(
                            'Report roads, streetlights, sanitation, water, electricity and '
                            "safety issues in your area — then track every one until it's "
                            'resolved. A few quick, optional steps and you\'re in.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary, height: 1.45),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 250),
                          child: const _OnboardingDots(count: 8, activeIndex: 0),
                        ),
                      ],
                    ),
                  ),
                ),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 280),
                  child: AppButton(label: 'Get Started', onPressed: onGetStarted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small decorative row of dots under the Welcome page's hero/copy — a
/// generic "there's more ahead" indicator distinct from the 7-segment
/// [ReportStepIndicator] progress bar steps 1-7 use (8 = the Welcome page
/// itself plus the 7 numbered steps).
class _OnboardingDots extends StatelessWidget {
  const _OnboardingDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == activeIndex ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == activeIndex ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}

/// Shared title + subtitle header above every numbered step's own content
/// — same role as `CreateReportScreen`'s `_StepScaffold`.
class _OnboardingStepScaffold extends StatelessWidget {
  const _OnboardingStepScaffold(
      {super.key, required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}

/// A single tappable choice row — shared by Step 1 (Language) and Step 4
/// (Age), the two steps that are just "pick one of a few options".
class _SelectableOptionTile extends StatelessWidget {
  const _SelectableOptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 22),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                ),
              ),
              if (isSelected)
                const CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.check, size: 14, color: AppColors.onPrimary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step 1 — Language.
class _LanguageStep extends StatelessWidget {
  const _LanguageStep({required this.selected, required this.onSelected});

  final OnboardingLanguage? selected;
  final ValueChanged<OnboardingLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final language in OnboardingLanguage.values) ...[
          _SelectableOptionTile(
            label: language.label,
            icon: Icons.language,
            isSelected: language == selected,
            onTap: () => onSelected(language),
          ),
          if (language != OnboardingLanguage.values.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Step 2 — About NAGARIK. Plain, static information hierarchy (heading +
/// body, repeated) — the reference screenshots' own structure for this
/// kind of screen, not their copy or branding. Deliberately not built on
/// top of `StaticContentScreen` (Settings -> About NAGARIK): that widget
/// owns its own `Scaffold`/`AppBar`, which doesn't fit being embedded as
/// one step's body here.
class _AboutStep extends StatelessWidget {
  const _AboutStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in _sections) ...[
          Text(section.$1, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(section.$2, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  static const List<(String, String)> _sections = [
    (
      'What NAGARIK does',
      'NAGARIK gives you a simple way to report civic issues in your '
          'area — potholes, broken streetlights, sanitation problems, water '
          'and electricity faults, and safety hazards — with a photo and an '
          'exact location.',
    ),
    (
      'Why report it',
      'Local authorities can only fix what they know about. A clear report '
          'with a photo and location gets an issue in front of the right '
          'team faster than waiting for someone else to notice it.',
    ),
    (
      'How it helps your area',
      'Every report is tracked from Submitted through In Review to '
          "Resolved, and you can browse what's already been reported nearby "
          '— so small problems get fixed before they become bigger ones.',
    ),
  ];
}

/// Step 3 — Mobile Number. Purely optional contact info, never used for
/// sign-in: Email/Password and "Continue with Google" remain the only two
/// ways into the app (see `AuthRepository` — no OTP path exists anywhere).
/// Saved locally by the parent's Continue handler and later written to the
/// real account's `user_metadata` once one exists (`AuthRepository`'s
/// `_syncPendingOnboardingPhone`) — see `OnboardingService`'s doc comment.
class _MobileNumberStep extends StatefulWidget {
  const _MobileNumberStep({required this.draft});

  final OnboardingDraft draft;

  @override
  State<_MobileNumberStep> createState() => _MobileNumberStepState();
}

class _MobileNumberStepState extends State<_MobileNumberStep> {
  late final TextEditingController _controller = TextEditingController(text: widget.draft.phoneNumber);

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: 'Mobile number (optional)',
      hintText: 'e.g. 98765 43210',
      controller: _controller,
      keyboardType: TextInputType.phone,
      maxLength: 15,
      prefixIcon: Icons.call_outlined,
      onChanged: (value) => widget.draft.phoneNumber = value,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Step 4 — Age.
class _AgeStep extends StatelessWidget {
  const _AgeStep({required this.selected, required this.onSelected});

  final AgeGroup? selected;
  final ValueChanged<AgeGroup> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final ageGroup in AgeGroup.values) ...[
          _SelectableOptionTile(
            label: ageGroup.label,
            icon: Icons.cake_outlined,
            isSelected: ageGroup == selected,
            onTap: () => onSelected(ageGroup),
          ),
          if (ageGroup != AgeGroup.values.last) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Step 5 — Data & Privacy. Two switches that preview the two permissions
/// Step 6 actually requests, so turning one off here means Step 6 won't
/// bother triggering that OS prompt at all (see `_PermissionsStep`).
class _PrivacyStep extends StatefulWidget {
  const _PrivacyStep({required this.draft});

  final OnboardingDraft draft;

  @override
  State<_PrivacyStep> createState() => _PrivacyStepState();
}

class _PrivacyStepState extends State<_PrivacyStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NAGARIK only ever asks for what report creation itself needs, '
          "and only when you're actively creating a report — never in the "
          'background. Turn either of these off now, or just say no to the '
          'real permission prompt on the next step; either way the app '
          'still works, with that one feature unavailable.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              _PrivacySwitchRow(
                icon: Icons.location_on_outlined,
                title: 'Location',
                subtitle: 'Tag a report with where the issue actually is.',
                value: widget.draft.locationPreviewEnabled,
                onChanged: (value) => setState(() => widget.draft.locationPreviewEnabled = value),
              ),
              const Divider(height: AppSpacing.lg),
              _PrivacySwitchRow(
                icon: Icons.camera_alt_outlined,
                title: 'Camera & photos',
                subtitle: 'Attach a photo of the issue to your report.',
                value: widget.draft.cameraPreviewEnabled,
                onChanged: (value) => setState(() => widget.draft.cameraPreviewEnabled = value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacySwitchRow extends StatelessWidget {
  const _PrivacySwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
      ],
    );
  }
}

/// Step 6 — Permissions. Real device permission prompts via
/// `permission_handler` (see `pubspec.yaml`'s comment on why this package
/// was added — `geolocator`/`image_picker` cover these permissions when a
/// report actually uses them, but neither exposes a way to just ask for
/// permission without also immediately fetching a position or opening the
/// camera, which is what this step needs). Denying either one here never
/// blocks Continue — the person can always grant it later, from the
/// report-creation screens that actually use it, or from device Settings.
class _PermissionsStep extends StatefulWidget {
  const _PermissionsStep({required this.draft});

  final OnboardingDraft draft;

  @override
  State<_PermissionsStep> createState() => _PermissionsStepState();
}

class _PermissionsStepState extends State<_PermissionsStep> {
  PermissionStatus? _locationStatus;
  PermissionStatus? _cameraStatus;
  bool _isRequestingLocation = false;
  bool _isRequestingCamera = false;

  Future<void> _requestLocation() async {
    setState(() => _isRequestingLocation = true);
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    setState(() {
      _locationStatus = status;
      _isRequestingLocation = false;
    });
  }

  Future<void> _requestCamera() async {
    setState(() => _isRequestingCamera = true);
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _cameraStatus = status;
      _isRequestingCamera = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PermissionCard(
          icon: Icons.location_on_outlined,
          title: 'Location',
          rationale: 'So a report can be tagged with exactly where the issue is.',
          previewEnabled: widget.draft.locationPreviewEnabled,
          status: _locationStatus,
          isRequesting: _isRequestingLocation,
          onAllow: _requestLocation,
        ),
        const SizedBox(height: AppSpacing.md),
        _PermissionCard(
          icon: Icons.camera_alt_outlined,
          title: 'Camera & photos',
          rationale: 'So you can attach a photo of the issue to your report.',
          previewEnabled: widget.draft.cameraPreviewEnabled,
          status: _cameraStatus,
          isRequesting: _isRequestingCamera,
          onAllow: _requestCamera,
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.rationale,
    required this.previewEnabled,
    required this.status,
    required this.isRequesting,
    required this.onAllow,
  });

  final IconData icon;
  final String title;
  final String rationale;
  final bool previewEnabled;
  final PermissionStatus? status;
  final bool isRequesting;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  previewEnabled
                      ? rationale
                      : 'You turned this off on the Data & Privacy step — you can still '
                          "grant it later from this app's settings if you change your mind.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (previewEnabled) _PermissionAction(status: status, isRequesting: isRequesting, onAllow: onAllow),
        ],
      ),
    );
  }
}

class _PermissionAction extends StatelessWidget {
  const _PermissionAction({required this.status, required this.isRequesting, required this.onAllow});

  final PermissionStatus? status;
  final bool isRequesting;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    if (isRequesting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.primary),
      );
    }
    if (status != null && status!.isGranted) {
      return const Icon(Icons.check_circle, color: AppColors.success, size: 24);
    }
    if (status != null && status!.isPermanentlyDenied) {
      return TextButton(onPressed: openAppSettings, child: const Text('Settings'));
    }
    return OutlinedButton(onPressed: onAllow, child: const Text('Allow'));
  }
}

/// Step 7 — Preferences. "Only useful NAGARIK preferences" per the brief —
/// the real, already-persisted theme setting (Settings -> Theme
/// preference's own `themePreferenceProvider`, not a duplicate of it) plus
/// a read-back of the Step 1 language choice with a link to change it.
/// Deliberately does not add any alert/SOS/emergency-contact style
/// preference — out of scope for this app.
class _PreferencesStep extends ConsumerWidget {
  const _PreferencesStep({required this.language, required this.onEditLanguage});

  final OnboardingLanguage? language;
  final VoidCallback onEditLanguage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(themePreferenceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            children: [
              for (final preference in AppThemePreference.values) ...[
                _PreferenceOptionRow(
                  icon: switch (preference) {
                    AppThemePreference.system => Icons.brightness_auto_outlined,
                    AppThemePreference.light => Icons.light_mode_outlined,
                    AppThemePreference.dark => Icons.dark_mode_outlined,
                  },
                  label: preference.label,
                  isSelected: preference == themePreference,
                  onTap: () => ref.read(themePreferenceProvider.notifier).setPreference(preference),
                ),
                if (preference != AppThemePreference.values.last) const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Language', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.language, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  language?.label ?? 'Not set',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: onEditLanguage, child: const Text('Change')),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreferenceOptionRow extends StatelessWidget {
  const _PreferenceOptionRow({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            if (isSelected) const Icon(Icons.check, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
