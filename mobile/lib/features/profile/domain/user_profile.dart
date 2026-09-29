/// The authenticated user's basic details, as returned by `GET /users/me`.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
  });

  final String id;
  final String? email;
  final String? fullName;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
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
