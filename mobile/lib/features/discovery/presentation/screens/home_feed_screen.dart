import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/core/routing/app_drawer.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:nagarik/features/discovery/presentation/widgets/category_grid.dart';
import 'package:nagarik/features/discovery/presentation/widgets/discovery_section_header.dart';
import 'package:nagarik/features/discovery/presentation/widgets/location_access_card.dart';
import 'package:nagarik/features/profile/presentation/providers/profile_providers.dart';
import 'package:nagarik/features/profile/presentation/widgets/profile_avatar_button.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/app_search_field.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/logo.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';
import 'package:nagarik/shared/widgets/skeleton.dart';

/// A directly-showable message for the Nearby Issues section's error state
/// — [LocationException] and [ApiException] both already carry one
/// (`.message`), so this just picks it out instead of falling through to
/// either exception type's less friendly `toString()`.
String _nearbyErrorMessage(AppLocalizations l10n, Object error) {
  if (error is LocationException) return error.message;
  if (error is ApiException) return error.message;
  return l10n.homeNearbyErrorFallback;
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: l10n.homeMenuTooltip,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Logo(size: 36, transparent: true),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'NAGARIK',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
        actions: const [ProfileAvatarButton()],
      ),
      drawer: const AppDrawer(activeRoute: '/home'),
      body: RefreshIndicator(
        onRefresh: () => _onRefresh(ref),
        child: ResponsiveCenter(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: const [
              FadeSlideIn(child: _Greeting()),
              SizedBox(height: AppSpacing.md),
              FadeSlideIn(delay: Duration(milliseconds: 60), child: _SearchShortcut()),
              SizedBox(height: AppSpacing.md),
              FadeSlideIn(delay: Duration(milliseconds: 100), child: LocationAccessCard()),
              SizedBox(height: AppSpacing.lg),
              FadeSlideIn(delay: Duration(milliseconds: 140), child: _CategorySection()),
              SizedBox(height: AppSpacing.lg),
              FadeSlideIn(delay: Duration(milliseconds: 180), child: _NearbyIssuesSection()),
              SizedBox(height: AppSpacing.lg),
              FadeSlideIn(delay: Duration(milliseconds: 220), child: _RecentReportsSection()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final fullName = profileAsync.asData?.value.displayName;
    final firstName = fullName == null ? null : fullName.trim().split(RegExp(r'\s+')).first;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstName != null && firstName.isNotEmpty ? l10n.homeGreetingNamed(firstName) : l10n.homeGreeting,
          style: textTheme.headlineMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.homeTagline, style: textTheme.bodyMedium),
      ],
    );
  }
}

class _SearchShortcut extends StatelessWidget {
  const _SearchShortcut();

  @override
  Widget build(BuildContext context) {
    return AppSearchField(readOnly: true, onTap: () => context.go('/search'));
  }
}

class _NearbyIssuesSection extends ConsumerWidget {
  const _NearbyIssuesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final nearbyAsync = ref.watch(nearbyReportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverySectionHeader(
          title: l10n.homeNearbyIssues,
          onSeeAll: () => context.go('/search?nearby=true'),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 190,
          child: nearbyAsync.when(
            loading: () => const SkeletonReportRow(),
            error: (error, stackTrace) => _InlineMessage(
              icon: error is ApiException && error.isNetworkError
                  ? Icons.wifi_off_outlined
                  : Icons.location_off_outlined,
              message: _nearbyErrorMessage(l10n, error),
              actionLabel: l10n.homeRetry,
              onAction: () => ref.invalidate(homeLocationProvider),
            ),
            data: (page) => page.items.isEmpty
                ? _InlineMessage(
                    icon: Icons.explore_off_outlined,
                    message: l10n.homeNearbyEmpty,
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: page.items.length,
                    separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final report = page.items[index];
                      return SizedBox(
                        width: 280,
                        child: FadeSlideIn(
                          delay: Duration(milliseconds: 40 * index),
                          child: ReportCard(
                            title: report.category.localizedLabel(l10n),
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
                        ),
                      );
                    },
                  ),
          ),
        ),
        // Lightweight shortcut only — the map itself lives in Search and
        // is not loaded on Home.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/search?nearby=true&view=map'),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(l10n.homeViewNearbyOnMap),
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tapping a card starts the guided Report Issue flow with that
        // category already selected; browsing existing reports by category
        // lives in Search & Discover.
        DiscoverySectionHeader(
          title: l10n.homeReportAnIssue,
          onSeeAll: () => context.push('/report/create'),
        ),
        const SizedBox(height: AppSpacing.sm),
        CategoryGrid(
          onCategoryTap: (category) => context.push('/report/create?category=${category.name}'),
        ),
      ],
    );
  }
}

class _RecentReportsSection extends ConsumerWidget {
  const _RecentReportsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final feedAsync = ref.watch(homeFeedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverySectionHeader(
          title: l10n.homeRecentReports,
          onSeeAll: () => context.go('/search?all=true'),
        ),
        const SizedBox(height: AppSpacing.sm),
        feedAsync.when(
          loading: () => const SkeletonReportList(count: 2, padding: EdgeInsets.zero),
          error: (error, stackTrace) => SizedBox(
            height: 160,
            child: ErrorView.forError(
              error,
              onRetry: () => ref.invalidate(homeFeedProvider),
              fallbackMessage: l10n.homeRecentLoadError,
            ),
          ),
          data: (page) => page.items.isEmpty
              ? SizedBox(
                  height: 160,
                  child: EmptyView.noReports(
                    actionLabel: l10n.homeReportAnIssue,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        for (var index = 0; index < reports.length; index++) ...[
          FadeSlideIn(
            delay: Duration(milliseconds: 40 * index),
            child: ReportCard(
              title: reports[index].category.localizedLabel(l10n),
              description: reports[index].description,
              category: reports[index].category,
              status: reports[index].status,
              city: reports[index].city,
              pinCode: reports[index].pinCode,
              referenceId: reports[index].referenceId,
              imageUrl:
                  reports[index].imageUrls.isNotEmpty ? reports[index].imageUrls.first : null,
              date: reports[index].createdAt,
              onTap: () => context.push('/report/${reports[index].id}'),
            ),
          ),
          if (index != reports.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
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
