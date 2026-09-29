import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/core/network/api_client.dart';
import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/data/reports_repository.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/domain/reports_page.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

/// Home tab feed (Step 7 baseline): the most recent reports across all
/// cities, unfiltered. Pull-to-refresh calls `ref.invalidate(homeFeedProvider)`.
final homeFeedProvider = FutureProvider.autoDispose<ReportsPage>((ref) {
  return ref.watch(reportsRepositoryProvider).getReports(limit: 20);
});

/// The signed-in user's own reports, for the Profile tab's report history
/// (Step 7). Watching [currentUserProvider] means this automatically
/// refetches on login and clears on logout, same reasoning as
/// `currentUserProfileProvider` in the profile feature.
final myReportsProvider = FutureProvider.autoDispose<ReportsPage>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(reportsRepositoryProvider).getReports(mine: true, limit: 20);
});

/// A single report by id, for the report detail screen (Step 7).
final reportByIdProvider = FutureProvider.autoDispose.family<Report, String>((ref, id) {
  return ref.watch(reportsRepositoryProvider).getReport(id);
});
