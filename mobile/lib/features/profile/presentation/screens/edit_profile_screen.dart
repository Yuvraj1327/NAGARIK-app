import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/app_text_field.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';

/// Profile -> Edit Profile.
///
/// Only the display name is actually editable here: it's the one profile
/// field this architecture stores anywhere mutable (Supabase Auth's
/// `user_metadata`, updated via `AuthRepository.updateFullName` — see that
/// method's doc comment for why a `refreshSession()` call is bundled with
/// it). The registered email is shown read-only — changing it is a
/// separate, bigger flow (Supabase requires confirming the new address
/// before it takes effect) that's out of scope for this step; there's
/// nowhere else in this codebase's schema for a phone number, bio, or
/// avatar to actually live, so adding fields for those here would just be
/// UI with nothing underneath it.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  bool _isSubmitting = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).updateFullName(_fullNameController.text.trim());
      // Belt-and-braces alongside the auth-state-driven refresh: guarantees
      // the Profile screen shows the new name the moment we navigate back,
      // rather than depending on stream-event timing.
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      context.pop();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your profile. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: const PrimaryAppBar(title: 'Edit Profile'),
      body: profileAsync.when(
        loading: () => const LoadingView(message: 'Loading your profile…'),
        error: (error, stackTrace) => ErrorView.forError(
          error,
          onRetry: () => ref.invalidate(currentUserProfileProvider),
          fallbackMessage: 'Could not load your profile. Please try again.',
        ),
        data: (profile) {
          // `ref.watch` re-runs this builder on every rebuild, so only
          // seed the controller once — otherwise the user's in-progress
          // edit would be clobbered by the still-old cached value on an
          // unrelated rebuild.
          if (!_prefilled) {
            _fullNameController.text = profile.fullName ?? '';
            _prefilled = true;
          }

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'Full name',
                    controller: _fullNameController,
                    prefixIcon: Icons.badge_outlined,
                    maxLength: 100,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return 'Full name is required.';
                      if (name.length < 2) return 'Full name is too short.';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Email',
                    controller: TextEditingController(text: profile.email ?? ''),
                    prefixIcon: Icons.email_outlined,
                    enabled: false,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Your registered email can\'t be changed here.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Save changes',
                    isLoading: _isSubmitting,
                    onPressed: _handleSave,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
