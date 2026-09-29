import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';

/// Home tab / main report feed.
///
/// Step 7 connects this to the real `GET /reports` feed — the most recent
/// reports across all cities, unfiltered. Filtering by category, status,
/// city/PIN, or "nearby" lives in the Search tab (Step 8), which is where
/// the app's discovery brief calls for those controls.
class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(homeFeedProvider);
    await ref.read(homeFeedProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(homeFeedProvider);

    return Scaffold(
      appBar: const PrimaryAppBar(title: 'NAGARIK'),
      body: RefreshIndicator(
        onRefresh: () => _onRefresh(ref),
        child: feedAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(
                height: 320,
                child: LoadingView(message: 'Loading reports…'),
              ),
            ],
          ),
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 320,
                child: ErrorView(
                  message: 'Could not load the feed. Pull down to try again.',
                  onRetry: () => ref.invalidate(homeFeedProvider),
                ),
              ),
            ],
          ),
          data: (page) => page.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 100),
                    EmptyView(
                      icon: Icons.map_outlined,
                      title: 'No reports yet',
                      message: 'Civic issues reported near you will show up here.\n'
                          'Be the first to report one.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: page.items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final report = page.items[index];
                    return ReportCard(
                      title: report.category.label,
                      description: report.description,
                      category: report.category,
                      status: report.status,
                      city: report.city,
                      pinCode: report.pinCode,
                      onTap: () => context.push('/report/${report.id}'),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
