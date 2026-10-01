import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/core/utils/date_format.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/domain/report_share.dart';
import 'package:nagarik/features/reports/domain/report_timeline.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';
import 'package:nagarik/shared/widgets/responsive_center.dart';
import 'package:nagarik/shared/widgets/section_header.dart';
import 'package:nagarik/shared/widgets/status_badge.dart';
import 'package:nagarik/shared/widgets/status_timeline.dart';

/// Full report detail layout.
///
/// Step 7 wired this to `GET /reports/:id` — reachable by tapping any
/// `ReportCard` in the feed, search results, or "My Reports". Viewing a
/// report is public at the API level, so this endpoint works whether or not
/// the viewer is signed in — but the app's own router gates every screen
/// behind sign-in (see `docs/ARCHITECTURE.md`), so in practice this screen
/// is only ever reached by an already-authenticated user, which is why its
/// Share/Save actions below don't need a separate signed-out state. The My
/// Reports & Report Tracking upgrade added the reference id, split location
/// into city/PIN/coordinates rows, an always-shown "last updated" row, and
/// the status timeline. The Report Sharing & Saved Reports upgrade added
/// the Share and Save/Unsave app bar actions.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportByIdProvider(reportId));

    return Scaffold(
      appBar: PrimaryAppBar(
        title: 'Report Details',
        actions: reportAsync.maybeWhen(
          data: (report) => [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: () => Share.share(
                buildReportShareText(report),
                subject: 'NAGARIK Civic Report',
              ),
            ),
            _SaveReportAction(report: report),
          ],
          orElse: () => null,
        ),
      ),
      body: reportAsync.when(
        loading: () => const LoadingView(message: 'Loading report…'),
        error: (error, stackTrace) => ErrorView.forError(
          error,
          onRetry: () => ref.invalidate(reportByIdProvider(reportId)),
          fallbackMessage: 'Could not load this report. It may have been removed.',
        ),
        data: (report) => _ReportDetailBody(report: report),
      ),
    );
  }
}

/// The app bar's Save/Unsave (bookmark) icon button. A small stateful
/// widget of its own so the brief in-flight moment of a save/unsave call
/// only disables/spins this one icon, not the whole screen.
class _SaveReportAction extends ConsumerStatefulWidget {
  const _SaveReportAction({required this.report});

  final Report report;

  @override
  ConsumerState<_SaveReportAction> createState() => _SaveReportActionState();
}

class _SaveReportActionState extends ConsumerState<_SaveReportAction> {
  bool _isSubmitting = false;

  Future<void> _toggle() async {
    setState(() => _isSubmitting = true);
    final repository = ref.read(reportsRepositoryProvider);
    try {
      if (widget.report.isSaved) {
        await repository.unsaveReport(widget.report.id);
      } else {
        await repository.saveReport(widget.report.id);
      }
      // Both providers are re-fetched rather than updated optimistically —
      // a single extra request for a tap this infrequent is a fair trade
      // for never showing a saved state the backend didn't actually confirm.
      ref.invalidate(reportByIdProvider(widget.report.id));
      ref.invalidate(savedReportsProvider);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: Icon(widget.report.isSaved ? Icons.bookmark : Icons.bookmark_border),
      tooltip: widget.report.isSaved ? 'Remove from saved reports' : 'Save report',
      onPressed: _toggle,
    );
  }
}

class _ReportDetailBody extends StatelessWidget {
  const _ReportDetailBody({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ResponsiveCenter(
      child: FadeSlideIn(
        child: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (report.imageUrls.isEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.image_outlined, size: 48, color: AppColors.textSecondary),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: report.imageUrls.length,
              separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CachedNetworkImage(
                  imageUrl: report.imageUrls[index],
                  width: 240,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 240,
                    color: AppColors.border,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 240,
                    color: AppColors.border,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(report.category.icon, size: 22, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.category.label, style: textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        report.referenceId,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            StatusBadge(status: report.status),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(report.description, style: textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        _DetailRow(icon: Icons.location_city_outlined, label: 'City', value: report.city),
        const SizedBox(height: AppSpacing.sm),
        _DetailRow(icon: Icons.pin_drop_outlined, label: 'PIN code', value: report.pinCode),
        if (report.latitude != null && report.longitude != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            icon: Icons.my_location_outlined,
            label: 'Location',
            value:
                '${report.latitude!.toStringAsFixed(5)}, ${report.longitude!.toStringAsFixed(5)}',
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        _DetailRow(
          icon: Icons.schedule_outlined,
          label: 'Created',
          value: formatReportTimestamp(report.createdAt),
        ),
        const SizedBox(height: AppSpacing.sm),
        _DetailRow(
          icon: Icons.update_outlined,
          label: 'Updated',
          value: formatReportTimestamp(report.updatedAt),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        const SectionHeader(title: 'Status timeline'),
        const SizedBox(height: AppSpacing.sm),
        StatusTimeline(stages: timelineStagesForStatus(report.status)),
      ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text('$label: ', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        Expanded(child: Text(value, style: textTheme.bodyMedium)),
      ],
    );
  }
}
