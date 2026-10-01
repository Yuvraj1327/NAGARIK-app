import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/core/routing/app_drawer.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';
import 'package:nagarik/shared/widgets/skeleton.dart';

/// My Reports — a primary bottom-nav tab (Report Sharing, Saved Reports &
/// Final Feature Polish upgrade moved it here from a screen pushed off
/// Profile; also reachable from the app drawer, same route either way).
///
/// Shows only the signed-in caller's own reports (`myReportsProvider` calls
/// `GET /reports?mine=true`, which requires — and is scoped server-side
/// to — the caller's own `user_id`; see `backend/app/services/
/// reports_service.py`). Organizes them with the same All/Submitted/In
/// Review/Resolved chip-filter pattern the Search tab already uses for
/// status, rather than inventing a new pattern for the same idea.
class MyReportsScreen extends ConsumerStatefulWidget {
  const MyReportsScreen({super.key});

  @override
  ConsumerState<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends ConsumerState<MyReportsScreen> {
  /// null means "All".
  ReportStatus? _filter;

  Future<void> _onRefresh() async {
    ref.invalidate(myReportsProvider);
    await ref.read(myReportsProvider.future);
  }

  List<Report> _applyFilter(List<Report> reports) {
    if (_filter == null) return reports;
    return reports.where((report) => report.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final myReportsAsync = ref.watch(myReportsProvider);

    return Scaffold(
      appBar: const PrimaryAppBar(title: 'My Reports'),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ResponsiveCenter(
        child: myReportsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SkeletonReportList(count: 4),
            ],
          ),
          error: (error, stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: 320,
                child: ErrorView.forError(
                  error,
                  onRetry: () => ref.invalidate(myReportsProvider),
                  fallbackMessage: 'Could not load your reports. Pull down to try again.',
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
                  EmptyView.noReports(),
                ],
              );
            }

            final filtered = _applyFilter(page.items);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    0,
                  ),
                  child: _StatusFilterBar(
                    reports: page.items,
                    selected: _filter,
                    onSelected: (status) => setState(() => _filter = status),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            EmptyView(
                              icon: Icons.filter_alt_off_outlined,
                              title: 'No reports in this category',
                              message: 'Try a different filter above.',
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final report = filtered[index];
                            return FadeSlideIn(
                              delay: Duration(milliseconds: 30 * index),
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
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}

/// The All/Submitted/In Review/Resolved chip row, each labeled with how
/// many of the caller's reports currently fall into it — computed from
/// [reports] client-side rather than a separate request per chip (the
/// counts and the list share the one `myReportsProvider` fetch).
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.reports,
    required this.selected,
    required this.onSelected,
  });

  final List<Report> reports;
  final ReportStatus? selected;
  final ValueChanged<ReportStatus?> onSelected;

  int _countFor(ReportStatus? status) {
    if (status == null) return reports.length;
    return reports.where((report) => report.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            count: _countFor(null),
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final status in ReportStatus.values) ...[
            _FilterChip(
              label: status.label,
              count: _countFor(status),
              selected: selected == status,
              onTap: () => onSelected(status),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
