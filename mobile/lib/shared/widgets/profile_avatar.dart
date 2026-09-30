import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The signed-in user's profile photo, or a default initial-letter avatar
/// when they haven't set one (User Profile Photo upgrade). Used everywhere
/// the app shows the user's identity — the navigation drawer's header, the
/// Profile tab, and Edit Profile's photo picker — so all three stay
/// visually identical and share one fallback/error story.
///
/// [avatarUrl] is expected to be a short-lived *signed* URL (the avatars
/// Storage bucket is private — see `backend/app/services/profile_service.py`),
/// so this always fetches fresh rather than assuming it can cache the URL
/// itself across app restarts; [CachedNetworkImage] still avoids
/// re-downloading the same bytes on every rebuild within a session.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    this.radius = 32,
  });

  final String? avatarUrl;
  final String displayName;
  final double radius;

  String get _initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final theme = Theme.of(context);

    Widget fallback() => CircleAvatar(
          radius: radius,
          child: Text(_initial, style: theme.textTheme.headlineSmall),
        );

    if (url == null || url.isEmpty) return fallback();

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        // While loading and on any failure (an expired signed URL, no
        // network, a since-removed photo), fall back to the same initial
        // avatar rather than a blank box or a broken-image icon — a
        // profile photo that briefly can't load should never look broken.
        placeholder: (context, url) => fallback(),
        errorWidget: (context, url, error) => fallback(),
      ),
    );
  }
}
