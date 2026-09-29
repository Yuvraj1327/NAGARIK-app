import 'package:nagarik/core/constants/api_endpoints.dart';
import 'package:nagarik/core/network/api_client.dart';
import 'package:nagarik/features/profile/domain/user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfile> fetchCurrentUser() async {
    final response = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.currentUser);
    return UserProfile.fromJson(response.data!);
  }
}
