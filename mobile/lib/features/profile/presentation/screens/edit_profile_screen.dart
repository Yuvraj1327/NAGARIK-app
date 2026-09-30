import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/app_text_field.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';
import 'package:nagarik/shared/widgets/profile_avatar.dart';

/// Profile -> Edit Profile.
///
/// The display name and the profile photo (User Profile Photo upgrade) are
/// the two profile fields this architecture stores anywhere mutable —
/// Supabase Auth's `user_metadata` (full name) and the private `avatars`
/// Storage bucket + that same `user_metadata` (the photo's reference),
/// updated via `AuthRepository.updateFullName`/`updateAvatarPath` — see
/// those methods' doc comments for why a `refreshSession()` call is
/// bundled with each. The registered email is shown read-only — changing
/// it is a separate, bigger flow (Supabase requires confirming the new
/// address before it takes effect) that's out of scope for this step;
/// there's nowhere else in this codebase's schema for a phone number or
/// bio to actually live, so adding fields for those here would just be UI
/// with nothing underneath it.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isUpdatingPhoto = false;
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

  Future<void> _showPhotoActions({required bool hasPhoto}) async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Remove Photo', style: TextStyle(color: AppColors.error)),
                onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.remove),
              ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;
    if (action == _PhotoAction.camera) {
      await _pickAndUpload(ImageSource.camera);
    } else if (action == _PhotoAction.gallery) {
      await _pickAndUpload(ImageSource.gallery);
    } else {
      await _removePhoto();
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    XFile? picked;
    try {
      // Downscaled client-side: a profile photo is shown at most a few
      // hundred pixels across, and this keeps most photos comfortably
      // under the backend's 5 MB limit without a separate compression step.
      picked = await _picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    } catch (_) {
      _showMessage(
        source == ImageSource.camera
            ? 'Could not open the camera. Please try again.'
            : 'Could not open the photo library. Please try again.',
      );
      return;
    }
    if (picked == null) return;

    setState(() => _isUpdatingPhoto = true);
    try {
      final result = await ref.read(profileRepositoryProvider).uploadAvatar(picked);
      await ref.read(authRepositoryProvider).updateAvatarPath(result.avatarPath);
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      _showMessage('Profile photo updated.');
    } catch (_) {
      _showMessage('Could not upload your photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isUpdatingPhoto = true);
    try {
      await ref.read(profileRepositoryProvider).removeAvatar();
      await ref.read(authRepositoryProvider).updateAvatarPath(null);
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      _showMessage('Profile photo removed.');
    } catch (_) {
      _showMessage('Could not remove your photo. Please try again.');
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          final hasPhoto = profile.avatarUrl != null;

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ProfileAvatar(
                          avatarUrl: profile.avatarUrl,
                          displayName: profile.displayName,
                          radius: 48,
                        ),
                        if (_isUpdatingPhoto)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                shape: BoxShape.circle,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: CircularProgressIndicator(color: AppColors.onPrimary),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Material(
                            color: AppColors.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _isUpdatingPhoto
                                  ? null
                                  : () => _showPhotoActions(hasPhoto: hasPhoto),
                              child: const Padding(
                                padding: EdgeInsets.all(AppSpacing.xs),
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 18,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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

enum _PhotoAction { camera, gallery, remove }
