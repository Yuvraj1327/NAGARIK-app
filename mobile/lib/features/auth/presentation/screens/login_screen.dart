import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/app_text_field.dart';
import 'package:nagarik/shared/widgets/logo.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';

/// Login screen, wired to real Supabase Auth (Step 3).
///
/// On success there is deliberately no manual navigation here: the
/// router's `redirect` (see `core/routing/app_router.dart`) is driven by
/// the auth-state stream via `refreshListenable`, so it automatically
/// takes the user away from `/login` the moment sign-in succeeds.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _handleLogin() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authErrorGeneric)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // NAGARIK Theme upgrade: a fixed-height hero banner up top (the
    // uploaded `auth_hero.jpg`, shared with Signup and the Auth Welcome
    // screen) instead of the plain centered Logo this screen used to open
    // on. Capped between 220 and 320 logical pixels — a fraction of the
    // screen on a normal phone, never so tall it pushes the form below the
    // fold or, on a short device, so tall it fights the keyboard once a
    // field is focused.
    final heroHeight = (MediaQuery.of(context).size.height * 0.34).clamp(220.0, 320.0);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          // Scale+fade+slide entrance (NAGARIK Theme upgrade) — fast,
          // subtle, matches `FadeSlideIn`'s existing use everywhere else
          // in the app rather than a one-off animation just for this image.
          FadeSlideIn(
            duration: const Duration(milliseconds: 420),
            beginScale: 0.94,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: SizedBox(
                width: double.infinity,
                height: heroHeight,
                // The photo is always shown clear and unchanged — focusing a
                // form field below never blurs or tints it.
                child: Image.asset(
                  'assets/images/auth_hero.jpg',
                  width: double.infinity,
                  height: heroHeight,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: ResponsiveCenter(
                  maxWidth: 480,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 80),
                            child: Column(
                              children: [
                                const Center(child: Logo(size: 76, transparent: true)),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  l10n.authCivicGoodTagline,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 140),
                            child: AppTextField(
                              label: l10n.authEmail,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.email_outlined,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) return l10n.authEmailRequired;
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                                  return l10n.authEmailInvalid;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 180),
                            child: AppTextField(
                              label: l10n.authPassword,
                              controller: _passwordController,
                              obscureText: true,
                              prefixIcon: Icons.lock_outline,
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return l10n.authPasswordTooShort;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 220),
                            child: AppButton(
                              label: l10n.authLogIn,
                              isLoading: _isSubmitting,
                              onPressed: _handleLogin,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 260),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(l10n.authNoAccount),
                                TextButton(
                                  onPressed: () => context.push('/signup'),
                                  child: Text(l10n.authRegister),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
