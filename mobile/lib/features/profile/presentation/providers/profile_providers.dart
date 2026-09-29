import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/core/network/api_client.dart';
import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/features/profile/data/profile_repository.dart';
import 'package:nagarik/features/profile/domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

/// Fetches the signed-in user's profile from the backend. Watching
/// [currentUserProvider] means this automatically refetches on login and
/// clears/stops on logout — the profile screen never shows a stale user's
/// data after switching accounts.
final currentUserProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(profileRepositoryProvider).fetchCurrentUser();
});
