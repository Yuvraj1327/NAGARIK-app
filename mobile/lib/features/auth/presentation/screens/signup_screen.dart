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

/// Signup screen, wired to real Supabase Auth (Step 3).
///
/// Handles both possible outcomes of `signUp()`: if the Supabase project
/// requires email confirmation (the default), no session is returned yet
/// and the user is told to check their email; if confirmation is
/// disabled, a session comes back immediately and the router's
/// `redirect` takes the user away from `/signup` automatically, the same
/// way it does after a successful login.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _handleSignup() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      final response = await ref.read(authRepositoryProvider).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          );

      if (!mounted) return;

      if (response.session == null) {
        // Email confirmation is required by this Supabase project's Auth
        // settings — there's no active session yet.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.authAccountCreated),
          ),
        );
        context.pop();
      }
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
    // NAGARIK Theme upgrade: same hero banner as Login, shorter since
    // Signup's form has more fields to fit above the fold.
    final heroHeight = (MediaQuery.of(context).size.height * 0.26).clamp(170.0, 260.0);
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
                                const Center(child: Logo(size: 68, transparent: true)),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  l10n.authCreateTitle,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  l10n.authCreateSubtitle,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 120),
                            child: AppTextField(
                              label: l10n.authFullName,
                              controller: _nameController,
                              prefixIcon: Icons.person_outline,
                              textInputAction: TextInputAction.next,
                              validator: (value) => (value == null || value.trim().isEmpty)
                                  ? l10n.authNameRequired
                                  : null,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 150),
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
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.length < 6) {
                                  return l10n.authPasswordTooShort;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 210),
                            child: AppTextField(
                              label: l10n.authConfirmPassword,
                              controller: _confirmController,
                              obscureText: true,
                              prefixIcon: Icons.lock_outline,
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return l10n.authPasswordsMismatch;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 250),
                            child: AppButton(
                              label: l10n.authCreateAccount,
                              isLoading: _isSubmitting,
                              onPressed: _handleSignup,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 280),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(l10n.authHaveAccount),
                                TextButton(
                                  onPressed: () => context.pop(),
                                  child: Text(l10n.authLogIn),
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}
