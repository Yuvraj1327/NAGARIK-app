import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nagarik/core/constants/api_endpoints.dart';
import 'package:nagarik/core/network/api_client.dart';
import 'package:nagarik/features/profile/domain/avatar_upload_result.dart';
import 'package:nagarik/features/profile/domain/user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfile> fetchCurrentUser() async {
    final response = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.currentUser);
    return UserProfile.fromJson(response.data!);
  }

  /// Uploads or replaces the signed-in user's profile photo (User Profile
  /// Photo upgrade). The caller (Edit Profile) is responsible for then
  /// calling `AuthRepository.updateAvatarPath` with the returned
  /// [AvatarUploadResult.avatarPath] — this repository only talks to the
  /// backend/Storage, never to Supabase Auth directly (see
  /// `AuthRepository`'s doc comment for why that split exists).
  Future<AvatarUploadResult> uploadAvatar(XFile image) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: image.name),
    });

    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.myAvatar,
      data: formData,
    );
    return AvatarUploadResult.fromJson(response.data!);
  }

  /// Removes the signed-in user's profile photo. Idempotent on the backend
  /// — calling this with no photo set still succeeds.
  Future<void> removeAvatar() async {
    await _apiClient.delete<void>(ApiEndpoints.myAvatar);
  }
}
