import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:nagarik/shared/widgets/logo.dart';
import 'package:nagarik/shared/widgets/pill_button.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';

/// First-run onboarding: a Welcome page followed by seven optional steps
/// (Language, About, Mobile Number, Age, Data & Privacy, Permissions,
/// Preferences), recreated from the supplied reference screens — segmented
/// progress bar with a back arrow, large bold headings, rounded cards, and
/// full-width pill buttons — in NAGARIK's own palette, logo, and copy. It
/// hands off to the existing Auth Welcome screen (`/welcome`) unchanged.
///
/// Features from the reference that NAGARIK doesn't have are deliberately
/// not faked: no phone-OTP login (Email/Google remain the only sign-in
/// methods), no SOS/"I'm Safe", no alert radius/kinds or notifications, no
/// analytics/marketing consents.
///
/// Every step is skippable. The header "Skip" skips only the current step;
/// Welcome's top-right "Skip" leaves the whole flow.
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
  String? _phoneError;

  Future<void> _finish() async {
    await ref.read(onboardingServiceProvider).markFinished();
    if (!mounted) return;
    // Replaces the whole stack — nothing to come "back" to from auth.
    context.go('/welcome');
  }

  void _onGetStarted() => setState(() => _currentStep = 1);

  void _onBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else if (context.canPop()) {
      context.pop();
    }
  }

  void _editStep(int step) => setState(() => _currentStep = step);

  Future<void> _onContinue() async {
    // if-chain rather than `switch` (a non-empty Dart switch case can't
    // fall through, and only one step is active per call anyway).
    final onboarding = ref.read(onboardingServiceProvider);
    if (_currentStep == 1) {
      final language = _draft.language;
      if (language != null) await onboarding.setLanguage(language);
    }
    if (_currentStep == 3) {
      final digits = _draft.phoneNumber.trim();
      if (digits.isNotEmpty) {
        if (digits.length != 10) {
          setState(() => _phoneError = 'Enter a 10-digit mobile number, or skip this step.');
          return;
        }
        await onboarding.setPendingPhoneNumber('+91$digits');
      }
    }
    if (_currentStep == 5) {
      await onboarding.setConsents(
        location: _draft.locationPreviewEnabled,
        camera: _draft.cameraPreviewEnabled,
      );
    }
    await _advance();
  }

  Future<void> _onPickAge(AgeGroup ageGroup) async {
    _draft.ageGroup = ageGroup;
    await ref.read(onboardingServiceProvider).setAgeGroup(ageGroup);
    await _advance();
  }

  /// Skip only discards whatever the current step holds in [_draft] — it
  /// never saves anything, it just moves on.
  Future<void> _onSkipStep() => _advance();

  Future<void> _advance() async {
    if (_currentStep < _lastStep) {
      setState(() {
        _phoneError = null;
        _currentStep += 1;
      });
    } else {
      await _finish();
    }
  }

  Widget _buildStepBody() {
    switch (_currentStep) {
      case 1:
        return _LanguageStep(
          key: const ValueKey(1),
          selected: _draft.language ?? OnboardingLanguage.english,
          onSelected: (language) => setState(() => _draft.language = language),
        );
      case 2:
        return const _AboutStep(key: ValueKey(2));
      case 3:
        return _MobileNumberStep(
          key: const ValueKey(3),
          draft: _draft,
          errorText: _phoneError,
          onChanged: () {
            if (_phoneError != null) setState(() => _phoneError = null);
          },
        );
      case 4:
        return const _AgeStep(key: ValueKey(4));
      case 5:
        return _PrivacyStep(key: const ValueKey(5), draft: _draft);
      case 6:
        return _PermissionsStep(key: const ValueKey(6), draft: _draft);
      case 7:
      default:
        return _PreferencesStep(
          key: const ValueKey(7),
          language: _draft.language ?? OnboardingLanguage.english,
          onEditLanguage: () => _editStep(1),
        );
    }
  }

  Widget _buildBottomBar() {
    if (_currentStep == 4) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PillButton(label: "Yes, I'm 18 or older", onPressed: () => _onPickAge(AgeGroup.eighteenOrOlder)),
          const SizedBox(height: AppSpacing.sm),
          PillButton(
            label: "No, I'm under 18",
            variant: PillButtonVariant.outlined,
            onPressed: () => _onPickAge(AgeGroup.underEighteen),
          ),
        ],
      );
    }
    final label = switch (_currentStep) {
      2 => 'I understand, continue',
      5 => 'Continue with my choices',
      7 => 'Finish and open NAGARIK',
      _ => 'Continue',
    };
    return PillButton(
      label: label,
      variant: _currentStep == 6 ? PillButtonVariant.soft : PillButtonVariant.primary,
      onPressed: _onContinue,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0) {
      return _WelcomePage(onGetStarted: _onGetStarted, onSkip: _finish);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.sm, AppSpacing.xs, 0),
                child: Row(
                  children: [
                    IconButton(onPressed: _onBack, icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
                    Expanded(
                      child: ReportStepIndicator(stepCount: _lastStep, currentStep: _currentStep - 1),
                    ),
                    TextButton(
                      onPressed: _onSkipStep,
                      child: const Text('Skip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _buildStepBody(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: _buildBottomBar(),
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
                  child: PillButton(label: 'Get Started', onPressed: onGetStarted),
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

/// Big bold step title (+ optional subtitle), left-aligned like the
/// reference unless [center] is set (Language step).
class _OnboardingTitle extends StatelessWidget {
  const _OnboardingTitle({required this.title, this.subtitle, this.center = false});

  final String title;
  final String? subtitle;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = center ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: align,
          style: theme.textTheme.headlineMedium?.copyWith(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: align,
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ],
    );
  }
}

/// Step 1 — Language: centered logo and title, three radio rows.
class _LanguageStep extends StatelessWidget {
  const _LanguageStep({super.key, required this.selected, required this.onSelected});

  final OnboardingLanguage selected;
  final ValueChanged<OnboardingLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: Logo(size: 76)),
        const SizedBox(height: AppSpacing.lg),
        const _OnboardingTitle(
          title: 'Choose your language',
          subtitle: 'अपनी भाषा चुनें · तुमची भाषा निवडा',
          center: true,
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final language in OnboardingLanguage.values) ...[
          _LanguageRow(
            label: language.label,
            isSelected: language == selected,
            onTap: () => onSelected(language),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          'You can change this any time in Preferences.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: isSelected ? null : Border.all(color: AppColors.border, width: 2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Step 2 — About: logo, headline, three icon rows, and the "not an
/// emergency service" notice.
class _AboutStep extends StatelessWidget {
  const _AboutStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(alignment: Alignment.centerLeft, child: Logo(size: 64)),
        const SizedBox(height: AppSpacing.lg),
        const _OnboardingTitle(
          title: "Fix what's around you.",
          subtitle: 'Report it, track it, see it resolved.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const _InfoRow(
          icon: Icons.verified_outlined,
          title: 'Every report is tracked',
          body: 'Follow it from Submitted through In Review to Resolved.',
        ),
        const _InfoRow(
          icon: Icons.location_on_outlined,
          title: 'Pinned to the exact spot',
          body: 'A photo and a location help the right team find the problem.',
        ),
        const _InfoRow(
          icon: Icons.history,
          title: 'Everything in one place',
          body: 'Sign in to see all your reports in My Reports, and browse nearby ones.',
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.55),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone_outlined, color: AppColors.textPrimary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                    children: const [
                      TextSpan(
                        text: 'NAGARIK is not an emergency service. ',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: 'If you or someone is in danger, call 112.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 17)),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 3 — Mobile number: optional, +91 prefix cell plus digits. Saved
/// only as contact info (never used to sign in) — see `OnboardingService`.
class _MobileNumberStep extends StatefulWidget {
  const _MobileNumberStep({
    super.key,
    required this.draft,
    required this.errorText,
    required this.onChanged,
  });

  final OnboardingDraft draft;
  final String? errorText;
  final VoidCallback onChanged;

  @override
  State<_MobileNumberStep> createState() => _MobileNumberStepState();
}

class _MobileNumberStepState extends State<_MobileNumberStep> {
  late final TextEditingController _controller = TextEditingController(text: widget.draft.phoneNumber);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        const _OnboardingTitle(
          title: 'Your mobile number',
          subtitle: "Optional. It's only used if a reviewer needs to reach you about a report — "
              "you'll still sign in with email or Google.",
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Mobile number', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: hasError ? AppColors.error : AppColors.border, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Container(
                width: 72,
                alignment: Alignment.center,
                color: AppColors.background,
                child: const Text('+91', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  onChanged: (value) {
                    widget.draft.phoneNumber = value;
                    widget.onChanged();
                  },
                  decoration: const InputDecoration(
                    hintText: '98765 43210',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.errorText!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error)),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Step 4 — Age. The two answer buttons live in the screen's bottom bar
/// (tapping one records it and moves on); Skip is in the header.
class _AgeStep extends StatelessWidget {
  const _AgeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.xl),
      child: _OnboardingTitle(
        title: 'Are you 18 or older?',
        subtitle: 'This helps us follow data protection rules. It is entirely optional — '
            'you can skip it.',
      ),
    );
  }
}

/// Step 5 — Data & privacy: a "needed to sign in" box, then one switch per
/// consent. Both default to on; Step 6 only asks the OS for what's still on.
class _PrivacyStep extends StatefulWidget {
  const _PrivacyStep({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<_PrivacyStep> createState() => _PrivacyStepState();
}

class _PrivacyStepState extends State<_PrivacyStep> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OnboardingTitle(
          title: 'Your data, your choice',
          subtitle: 'Turn on only what you want. Each switch is a separate consent, and your '
              'phone still asks before anything is shared.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.55),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEEDED TO SIGN IN',
                style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Your email address', style: theme.textTheme.titleMedium?.copyWith(fontSize: 18)),
              const SizedBox(height: 2),
              Text(
                'To sign you in and keep your reports linked to you.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'YOU CHOOSE',
          style: theme.textTheme.bodySmall?.copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ConsentRow(
          title: 'Location',
          body: 'Tag a report with where the issue is, and show what is near you.',
          value: widget.draft.locationPreviewEnabled,
          onChanged: (value) => setState(() => widget.draft.locationPreviewEnabled = value),
        ),
        const Divider(height: 1),
        _ConsentRow(
          title: 'Camera & photos',
          body: 'Attach the photos you choose to a report.',
          value: widget.draft.cameraPreviewEnabled,
          onChanged: (value) => setState(() => widget.draft.cameraPreviewEnabled = value),
        ),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.md),
        Text(
          'You can continue with everything off. Features that need a consent you '
          "haven't given simply won't be available.",
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 18)),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Step 6 — Permissions: real OS prompts via `permission_handler`. Denying
/// (or a Step 5 opt-out) never blocks Continue.
class _PermissionsStep extends StatefulWidget {
  const _PermissionsStep({super.key, required this.draft});

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
        const _OnboardingTitle(
          title: 'Two phone permissions',
          subtitle: 'Your phone will ask you to confirm each one.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _PermissionCard(
          icon: Icons.location_on_outlined,
          title: 'Location',
          body: 'To place a report on the map and show what is near you.',
          buttonLabel: 'Allow while using the app',
          primaryButton: true,
          enabled: widget.draft.locationPreviewEnabled,
          status: _locationStatus,
          isRequesting: _isRequestingLocation,
          onAllow: _requestLocation,
        ),
        const SizedBox(height: AppSpacing.md),
        _PermissionCard(
          icon: Icons.photo_camera_outlined,
          title: 'Camera & photos',
          body: 'To attach a photo of the issue to your report.',
          buttonLabel: 'Allow camera',
          primaryButton: false,
          enabled: widget.draft.cameraPreviewEnabled,
          status: _cameraStatus,
          isRequesting: _isRequestingCamera,
          onAllow: _requestCamera,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Skipped one? You can still allow it later when you report an issue.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.primaryButton,
    required this.enabled,
    required this.status,
    required this.isRequesting,
    required this.onAllow,
  });

  final IconData icon;
  final String title;
  final String body;
  final String buttonLabel;
  final bool primaryButton;
  final bool enabled;
  final PermissionStatus? status;
  final bool isRequesting;
  final VoidCallback onAllow;

  Widget _action() {
    if (!enabled) return const SizedBox.shrink();
    final current = status;
    if (current != null && current.isGranted) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success),
          SizedBox(width: AppSpacing.xs),
          Text('Allowed', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success)),
        ],
      );
    }
    if (current != null && current.isPermanentlyDenied) {
      return PillButton(
        label: 'Open settings',
        variant: PillButtonVariant.outlined,
        onPressed: openAppSettings,
      );
    }
    return PillButton(
      label: buttonLabel,
      variant: primaryButton ? PillButtonVariant.primary : PillButtonVariant.outlined,
      isLoading: isRequesting,
      onPressed: onAllow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 19)),
                    const SizedBox(height: 2),
                    Text(
                      enabled
                          ? body
                          : 'You turned this off on the previous step. You can still allow it '
                              "later from your phone's settings.",
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: AppSpacing.md),
            _action(),
          ],
        ],
      ),
    );
  }
}

/// Step 7 — Preferences: appearance (the real, already-persisted theme
/// setting) as a segmented control, plus the chosen language with Change.
class _PreferencesStep extends ConsumerWidget {
  const _PreferencesStep({super.key, required this.language, required this.onEditLanguage});

  final OnboardingLanguage language;
  final VoidCallback onEditLanguage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themePreference = ref.watch(themePreferenceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _OnboardingTitle(
          title: 'Set up NAGARIK',
          subtitle: 'Last step. You can change this any time.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Appearance', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.55),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              for (final preference in AppThemePreference.values)
                Expanded(
                  child: GestureDetector(
                    onTap: () => ref.read(themePreferenceProvider.notifier).setPreference(preference),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: preference == themePreference ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: preference == themePreference
                            ? const [BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x1A12213A))]
                            : null,
                      ),
                      child: Text(
                        switch (preference) {
                          AppThemePreference.system => 'System',
                          AppThemePreference.light => 'Light',
                          AppThemePreference.dark => 'Dark',
                        },
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.55),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(Icons.language, color: AppColors.textPrimary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Language', style: theme.textTheme.bodyMedium),
                    Text(
                      language.label,
                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onEditLanguage,
                child: const Text('Change', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
