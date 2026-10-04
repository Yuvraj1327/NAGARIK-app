import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/animations/pressable_scale.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/logo.dart';

/// NAGARIK Theme upgrade: the app's new entry point for a signed-out user
/// (see `core/routing/app_router.dart` — `initialLocation: '/welcome'` and
/// the auth-gate `redirect`), replacing a cold start that went straight to
/// the Login form. An original, full-bleed design built around the
/// uploaded hero photo and the existing NAGARIK brand palette — the
/// reference screenshot supplied with this request was used only to gauge
/// the *category* of polish expected (full-bleed photo, legibility scrim,
/// bold type, a staggered entrance), never copied for its layout, purple/
/// dark color scheme, or any of its own branding.
///
/// Both actions here hand off to the existing, untouched auth flow:
/// "Log In" pushes [LoginScreen] (which itself links on to Signup/
/// "Register"); "Continue with Google" calls
/// `AuthRepository.signInWithGoogle` directly — on success there's
/// deliberately no manual navigation, exactly like [LoginScreen]'s
/// `_handleLogin`, since the router's `refreshListenable` already reacts
/// to the new session and leaves `/welcome` on its own.
class AuthWelcomeScreen extends ConsumerStatefulWidget {
  const AuthWelcomeScreen({super.key});

  @override
  ConsumerState<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends ConsumerState<AuthWelcomeScreen> {
  bool _isGoogleLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on StateError catch (error) {
      // "cancelled" is the person backing out of the account picker — a
      // routine dismissal, not a failure worth a SnackBar.
      if (!mounted || error.message == 'cancelled') return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign in with Google. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed hero photo — a slow, subtle zoom-out-to-rest on
          // first appearance (never a slide, so the horizon never tilts)
          // via FadeSlideIn's optional beginScale.
          FadeSlideIn(
            duration: const Duration(milliseconds: 700),
            beginScale: 1.08,
            child: Image.asset(
              'assets/images/auth_hero.jpg',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Legibility scrim — NAGARIK's own Navy Text color, not a
          // generic black or the reference's purple/dark tint, deepening
          // toward the bottom where the text and buttons sit.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x0012213A),
                  Color(0x3312213A),
                  Color(0xB312213A),
                  Color(0xF012213A),
                ],
                stops: [0.0, 0.42, 0.78, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    offset: const Offset(0, -0.3),
                    child: Row(
                      children: [
                        const Logo(size: 30),
                        const SizedBox(width: AppSpacing.xs),
                        const Text(
                          'NAGARIK',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 0.3,
                            shadows: [Shadow(blurRadius: 10, color: Colors.black38)],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                        child: const Text(
                          'See it. Report it.\nGet it fixed.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 32,
                            height: 1.15,
                            letterSpacing: -0.5,
                            shadows: [Shadow(blurRadius: 18, color: Colors.black45)],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 220),
                        child: Text(
                          'Report roads, streetlights, sanitation, water, electricity '
                          'and safety issues in your area — then track every one until '
                          "it's resolved.",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 260),
                        child: AppButton(
                          label: 'Log In',
                          onPressed: () => context.push('/login'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 300),
                        child: _GoogleSignInButton(
                          isLoading: _isGoogleLoading,
                          onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Continue with Google" button. Styled to sit on top of the hero photo's
/// scrim — a solid white pill (never transparent/outlined, which would be
/// unreadable there) with a small circular "G" mark rather than a bundled
/// multi-color Google logo asset, since none was supplied.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      enabled: onPressed != null,
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            disabledBackgroundColor: AppColors.surface,
            elevation: 2,
            shadowColor: const Color(0x3312213A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'G',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4285F4),
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
