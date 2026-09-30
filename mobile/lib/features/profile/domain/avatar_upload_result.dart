/// Response shape of `POST /users/me/avatar` (User Profile Photo upgrade).
///
/// [avatarPath] is what `AuthRepository.updateAvatarPath` writes back into
/// Supabase Auth's `user_metadata` — the backend has no way to write that
/// itself, only Storage bytes (see `backend/app/services/profile_service.py`).
/// [avatarUrl] is a freshly signed URL for immediately showing the new
/// photo without waiting for a full profile refetch.
class AvatarUploadResult {
  const AvatarUploadResult({required this.avatarPath, this.avatarUrl});

  final String avatarPath;
  final String? avatarUrl;

  factory AvatarUploadResult.fromJson(Map<String, dynamic> json) {
    return AvatarUploadResult(
      avatarPath: json['avatar_path'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
