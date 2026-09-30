/// The authenticated user's basic details, as returned by `GET /users/me`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? fullName;

  /// A freshly signed URL for the user's profile photo (User Profile Photo
  /// upgrade), or `null` if they haven't set one — see
  /// `shared/widgets/profile_avatar.dart` for the fallback that's shown
  /// when this is `null`.
  final String? avatarUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  /// The name shown in the UI: the user's full name if they gave one at
  /// signup, otherwise their email.
  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email ?? 'Citizen';
  }
}
