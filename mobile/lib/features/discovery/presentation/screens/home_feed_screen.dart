import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/core/routing/app_drawer.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:nagarik/features/discovery/presentation/widgets/category_grid.dart';
import 'package:nagarik/features/discovery/presentation/widgets/discovery_section_header.dart';
import 'package:nagarik/features/discovery/presentation/widgets/location_indicator.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/app_card.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';

/// A directly-showable message for the Nearby Issues section's error state
/// — [LocationException] and [ApiException] both already carry one
/// (`.message`), so this just picks it out instead of falling through to
/// either exception type's less friendly `toString()`.
String _nearbyErrorMessage(Object error) {
  if (error is LocationException) return error.message;
  if (error is ApiException) return error.message;
  return 'Could not find civic issues near you.';
}

/// Home tab — Location Discovery & Home upgrade.
///
/// Restructured from a single flat "most recent reports" list (Step 7)
/// into sections a citizen can scan at a glance: a greeting and location,
/// a shortcut into Search, a Nearby Issues preview (real device location,
/// gracefully degrading when it's unavailable), category shortcuts, a
/// Recent Reports preview, and a Report Issue CTA. Each section fetches
/// its own small amount of data through its own provider — deliberately,
/// so a failure in one (most likely Nearby Issues, if location is denied)
/// never blocks the others from rendering, matching the brief's "if
/// location permission is unavailable, the normal feed should still work".
class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(homeLocationProvider);
    ref.invalidate(homeFeedProvider);
    // nearbyReportsProvider depends on homeLocationProvider's `.future`, so
    // invalidating that above already queues its refetch too — this just
    // waits for both, independently, so one failing doesn't stop the other
    // from completing (and doesn't make pull-to-refresh itself throw).
    try {
      await ref.read(homeFeedProvider.future);
    } catch (_) {
      // Surfaced by the Recent Reports section's own error state.
    }
    try {
      await ref.read(nearbyReportsProvider.future);
    } catch (_) {
      // Surfaced by the Nearby Issues section's own error state.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const PrimaryAppBar(title: 'NAGARIK'),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () => _onRefresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: const [
            _GreetingAndLocation(),
            SizedBox(height: AppSpacing.md),
            _SearchShortcut(),
            SizedBox(height: AppSpacing.lg),
            _NearbyIssuesSection(),
            SizedBox(height: AppSpacing.lg),
            _CategorySection(),
            SizedBox(height: AppSpacing.lg),
            _RecentReportsSection(),
            SizedBox(height: AppSpacing.lg),
            _ReportIssueCta(),
          ],
        ),
      ),
    );
  }
}

class _GreetingAndLocation extends ConsumerWidget {
  const _GreetingAndLocation();

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final name = profileAsync.asData?.value.displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name != null ? '${_greeting()}, $name' : _greeting(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        const LocationIndicator(),
      ],
    );
  }
}

class _SearchShortcut extends StatelessWidget {
  const _SearchShortcut();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go('/search'),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Search civic issues…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NearbyIssuesSection extends ConsumerWidget {
  const _NearbyIssuesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyAsync = ref.watch(nearbyReportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverySectionHeader(
          title: 'Nearby Issues',
          onSeeAll: () => context.go('/search?nearby=true'),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 190,
          child: nearbyAsync.when(
            loading: () => const LoadingView(message: 'Finding issues near you…'),
            error: (error, stackTrace) => _InlineMessage(
              icon: error is ApiException && error.isNetworkError
                  ? Icons.wifi_off_outlined
                  : Icons.location_off_outlined,
              message: _nearbyErrorMessage(error),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(homeLocationProvider),
            ),
            data: (page) => page.items.isEmpty
                ? const _InlineMessage(
                    icon: Icons.explore_off_outlined,
                    message: 'Nothing has been reported near you recently.',
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: page.items.length,
                    separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final report = page.items[index];
                      return SizedBox(
                        width: 280,
                        child: ReportCard(
                          title: report.category.label,
                          description: report.description,
                          category: report.category,
                          status: report.status,
                          city: report.city,
                          pinCode: report.pinCode,
                          referenceId: report.referenceId,
                          imageUrl:
                              report.imageUrls.isNotEmpty ? report.imageUrls.first : null,
                          date: report.createdAt,
                          onTap: () => context.push('/report/${report.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DiscoverySectionHeader(title: 'Explore by Category'),
        const SizedBox(height: AppSpacing.sm),
        CategoryGrid(
          onCategoryTap: (category) => context.go('/search?category=${category.name}'),
        ),
      ],
    );
  }
}

class _RecentReportsSection extends ConsumerWidget {
  const _RecentReportsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(homeFeedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverySectionHeader(
          title: 'Recent Reports',
          onSeeAll: () => context.go('/search?all=true'),
        ),
        const SizedBox(height: AppSpacing.sm),
        feedAsync.when(
          loading: () => const SizedBox(
            height: 160,
            child: LoadingView(message: 'Loading recent reports…'),
          ),
          error: (error, stackTrace) => SizedBox(
            height: 160,
            child: ErrorView.forError(
              error,
              onRetry: () => ref.invalidate(homeFeedProvider),
              fallbackMessage: 'Could not load recent reports. Pull down to try again.',
            ),
          ),
          data: (page) => page.items.isEmpty
              ? SizedBox(
                  height: 160,
                  child: EmptyView.noReports(
                    actionLabel: 'Report an Issue',
                    onAction: () => context.push('/report/create'),
                  ),
                )
              : _RecentReportsList(reports: page.items.take(5).toList()),
        ),
      ],
    );
  }
}

class _RecentReportsList extends StatelessWidget {
  const _RecentReportsList({required this.reports});

  final List<Report> reports;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < reports.length; index++) ...[
          ReportCard(
            title: reports[index].category.label,
            description: reports[index].description,
            category: reports[index].category,
            status: reports[index].status,
            city: reports[index].city,
            pinCode: reports[index].pinCode,
            referenceId: reports[index].referenceId,
            imageUrl: reports[index].imageUrls.isNotEmpty ? reports[index].imageUrls.first : null,
            date: reports[index].createdAt,
            onTap: () => context.push('/report/${reports[index].id}'),
          ),
          if (index != reports.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ReportIssueCta extends StatelessWidget {
  const _ReportIssueCta();

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Report an Issue',
      icon: Icons.add_alert_outlined,
      onPressed: () => context.push('/report/create'),
    );
  }
}

/// Shared small "nothing to show, here's why" block for the Nearby Issues
/// section (used by its loading-adjacent error and empty states) — not a
/// full `EmptyView`/`ErrorView` because it needs to fit inside the
/// section's fixed-height horizontal strip rather than filling the screen.
class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
