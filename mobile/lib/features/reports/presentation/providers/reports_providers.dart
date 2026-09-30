import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/core/network/api_client.dart';
import 'package:nagarik/features/auth/presentation/providers/auth_providers.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/data/reports_repository.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/domain/report_stats.dart';
import 'package:nagarik/features/reports/domain/reports_page.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

/// The most recent reports across all cities, unfiltered — backs Home's
/// "Recent Reports" section (the Location Discovery & Home upgrade
/// restructured Home from a single flat feed into sections; this provider
/// kept its original Step 7 name and query since its data hasn't changed,
/// only where it's displayed). Deliberately has no location dependency at
/// all, so it renders regardless of whether `homeLocationProvider`
/// succeeds — see `discovery_providers.dart`'s `nearbyReportsProvider` for
/// the location-dependent counterpart. Pull-to-refresh calls
/// `ref.invalidate(homeFeedProvider)`.
final homeFeedProvider = FutureProvider.autoDispose<ReportsPage>((ref) {
  return ref.watch(reportsRepositoryProvider).getReports(limit: 20);
});

/// The signed-in user's own reports, for the My Reports screen (Step 7,
/// upgraded with status tabs and a reference id by the My Reports & Report
/// Tracking upgrade). Watching
/// [currentUserProvider] means this automatically refetches on login and
/// clears on logout, same reasoning as `currentUserProfileProvider` in the
/// profile feature.
///
/// Fetches up to the backend's `MAX_PAGE_SIZE` (50) in one call and the All/
/// Submitted/In Review/Resolved tabs on the My Reports screen filter that
/// single result client-side, rather than one network round trip per tab —
/// fewer requests, and switching tabs is instant. A citizen with more than
/// 50 lifetime reports (not a realistic case for this app) would only see
/// their most recent 50 here; real pagination for that is a natural future
/// addition (`ReportsPage.hasMore` already supports it) but is out of scope
/// for this step.
final myReportsProvider = FutureProvider.autoDispose<ReportsPage>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(reportsRepositoryProvider).getReports(mine: true, limit: 50);
});

/// A single report by id, for the report detail screen (Step 7).
final reportByIdProvider = FutureProvider.autoDispose.family<Report, String>((ref, id) {
  return ref.watch(reportsRepositoryProvider).getReport(id);
});

/// Per-status report counts for the Profile screen's stat tiles. Watching
/// [currentUserProvider] gives it the same login/logout-refresh behavior as
/// [myReportsProvider] and [currentUserProfileProvider].
final reportStatsProvider = FutureProvider.autoDispose<ReportStats>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(reportsRepositoryProvider).getReportStats();
});

/// The signed-in caller's saved (bookmarked) reports (Profile -> My
/// Activity -> Saved Reports; Report Sharing & Saved Reports upgrade).
/// Watching [currentUserProvider] gives it the same login/logout-refresh
/// behavior as [myReportsProvider]/[reportStatsProvider]. Invalidated
/// after every save/unsave (see `report_detail_screen.dart` and
/// `saved_reports_screen.dart`) so the list is never stale.
final savedReportsProvider = FutureProvider.autoDispose<ReportsPage>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(reportsRepositoryProvider).getSavedReports(limit: 50);
});
