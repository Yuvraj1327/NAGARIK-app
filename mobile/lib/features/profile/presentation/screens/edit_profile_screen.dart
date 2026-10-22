import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/app_text_field.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';
import 'package:nagarik/shared/widgets/profile_avatar.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';

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
  final _phoneController = TextEditingController();
  final _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _isUpdatingPhoto = false;
  bool _prefilled = false;
  String? _initialPhone;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _isSubmitting = true);
    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.updateFullName(_fullNameController.text.trim());
      // Optional: an empty field clears the stored number.
      final digits = _phoneController.text.trim();
      final newPhone = digits.isEmpty ? null : '+91$digits';
      if (newPhone != _initialPhone) await auth.updatePhoneNumber(newPhone);
      // Belt-and-braces alongside the auth-state-driven refresh: guarantees
      // the Profile screen shows the new name the moment we navigate back,
      // rather than depending on stream-event timing.
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profProfileUpdated)),
      );
      context.pop();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profUpdateError)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showPhotoActions({required bool hasPhoto}) async {
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.profTakePhoto),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profChooseFromGallery),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(l10n.profRemovePhoto, style: TextStyle(color: AppColors.error)),
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
    final l10n = AppLocalizations.of(context);
    XFile? picked;
    try {
      // Downscaled client-side: a profile photo is shown at most a few
      // hundred pixels across, and this keeps most photos comfortably
      // under the backend's 5 MB limit without a separate compression step.
      picked = await _picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    } catch (_) {
      _showMessage(
        source == ImageSource.camera
            ? l10n.profCameraError
            : l10n.profLibraryError,
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
      _showMessage(l10n.profPhotoUpdated);
    } catch (_) {
      _showMessage(l10n.profPhotoUploadError);
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isUpdatingPhoto = true);
    try {
      await ref.read(profileRepositoryProvider).removeAvatar();
      await ref.read(authRepositoryProvider).updateAvatarPath(null);
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      _showMessage(l10n.profPhotoRemoved);
    } catch (_) {
      _showMessage(l10n.profPhotoRemoveError);
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: PrimaryAppBar(title: l10n.profEditProfile),
      body: profileAsync.when(
        loading: () => LoadingView(message: l10n.profLoadingProfile),
        error: (error, stackTrace) => ErrorView.forError(
          error,
          onRetry: () => ref.invalidate(currentUserProfileProvider),
          fallbackMessage: l10n.profLoadError,
        ),
        data: (profile) {
          // `ref.watch` re-runs this builder on every rebuild, so only
          // seed the controller once — otherwise the user's in-progress
          // edit would be clobbered by the still-old cached value on an
          // unrelated rebuild.
          if (!_prefilled) {
            _fullNameController.text = profile.fullName ?? '';
            _initialPhone = profile.phoneOrNull;
            // Shown without the fixed +91 prefix, as on the onboarding step.
            _phoneController.text = (_initialPhone ?? '').replaceFirst(RegExp(r'^\+91'), '');
            _prefilled = true;
          }
          final hasPhoto = profile.avatarUrl != null;

          return ResponsiveCenter(
            maxWidth: 480,
            child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: FadeSlideIn(child: Column(
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
                    label: l10n.profFullName,
                    controller: _fullNameController,
                    prefixIcon: Icons.badge_outlined,
                    maxLength: 100,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return l10n.profFullNameRequired;
                      if (name.length < 2) return l10n.profFullNameTooShort;
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: l10n.profMobileOptional,
                    controller: _phoneController,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final digits = value?.trim() ?? '';
                      if (digits.isEmpty) return null;
                      if (digits.length != 10) {
                        return l10n.profMobileInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: l10n.profEmail,
                    controller: TextEditingController(text: profile.email ?? ''),
                    prefixIcon: Icons.email_outlined,
                    enabled: false,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.profEmailReadOnly,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: l10n.profSaveChanges,
                    isLoading: _isSubmitting,
                    onPressed: _handleSave,
                  ),
                ],
              )),
            ),
          ),
          );
        },
      ),
    );
  }
}

enum _PhotoAction { camera, gallery, remove }
