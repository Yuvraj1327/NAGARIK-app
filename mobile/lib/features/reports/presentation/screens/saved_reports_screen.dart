import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';

/// Profile -> My Activity -> Saved Reports (also reachable from the app
/// drawer). Report Sharing & Saved Reports upgrade: backed for real by
/// `GET /reports/saved` — each card uses the exact same `ReportCard` as
/// Home/Search/My Reports, wrapped in a swipe-to-remove `Dismissible` (the
/// screen's one addition specific to "saved" — removing a bookmark from
/// here doesn't need a second UI, just an easy way to unsave from the list
/// that already shows it).
class SavedReportsScreen extends ConsumerWidget {
  const SavedReportsScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(savedReportsProvider);
    await ref.read(savedReportsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedReportsAsync = ref.watch(savedReportsProvider);

    return Scaffold(
      appBar: const PrimaryAppBar(title: 'Saved Reports'),
      body: RefreshIndicator(
        onRefresh: () => _onRefresh(ref),
        child: savedReportsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 320, child: LoadingView(message: 'Loading saved reports…')),
            ],
          ),
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 320,
                child: ErrorView.forError(
                  error,
                  onRetry: () => ref.invalidate(savedReportsProvider),
                  fallbackMessage: 'Could not load saved reports. Pull down to try again.',
                ),
              ),
            ],
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 100),
                  EmptyView.noSavedReports(),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: page.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _SavedReportCard(report: page.items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _SavedReportCard extends ConsumerWidget {
  const _SavedReportCard({required this.report});

  final Report report;

  Future<bool> _unsave(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(reportsRepositoryProvider).unsaveReport(report.id);
      return true;
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(report.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _unsave(context, ref),
      // Only invalidated once the dismiss animation has actually finished —
      // invalidating any earlier (e.g. inside confirmDismiss) would rebuild
      // this list, and the item this Dismissible belongs to, while its own
      // removal animation is still playing.
      onDismissed: (_) => ref.invalidate(savedReportsProvider),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(28),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.bookmark_remove_outlined, color: AppColors.error),
      ),
      child: ReportCard(
        title: report.category.label,
        description: report.description,
        category: report.category,
        status: report.status,
        city: report.city,
        pinCode: report.pinCode,
        referenceId: report.referenceId,
        imageUrl: report.imageUrls.isNotEmpty ? report.imageUrls.first : null,
        date: report.createdAt,
        onTap: () => context.push('/report/${report.id}'),
      ),
    );
  }
}
