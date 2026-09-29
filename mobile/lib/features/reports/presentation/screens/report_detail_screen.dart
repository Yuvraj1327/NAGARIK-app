import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/core/utils/date_format.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';
import 'package:nagarik/shared/widgets/status_badge.dart';

/// Full report detail layout.
///
/// Step 7 wires this to `GET /reports/:id` — reachable by tapping any
/// `ReportCard` in the feed, search results, or "your reports". Viewing a
/// report is public, so this works whether or not the viewer is signed in.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportByIdProvider(reportId));

    return Scaffold(
      appBar: const PrimaryAppBar(title: 'Report Details'),
      body: reportAsync.when(
        loading: () => const LoadingView(message: 'Loading report…'),
        error: (error, stackTrace) => ErrorView(
          message: 'Could not load this report. It may have been removed.',
          onRetry: () => ref.invalidate(reportByIdProvider(reportId)),
        ),
        data: (report) => _ReportDetailBody(report: report),
      ),
    );
  }
}

class _ReportDetailBody extends StatelessWidget {
  const _ReportDetailBody({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
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
          children: [
            Icon(report.category.icon, size: 22, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(report.category.label, style: textTheme.titleLarge),
            ),
            StatusBadge(status: report.status),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(report.description, style: textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        _DetailRow(
          icon: Icons.location_on_outlined,
          label: 'Location',
          value: '${report.city} · ${report.pinCode}',
        ),
        if (report.latitude != null && report.longitude != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            icon: Icons.my_location_outlined,
            label: 'Coordinates',
            value:
                '${report.latitude!.toStringAsFixed(5)}, ${report.longitude!.toStringAsFixed(5)}',
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        _DetailRow(
          icon: Icons.schedule_outlined,
          label: 'Reported',
          value: formatReportTimestamp(report.createdAt),
        ),
        if (report.updatedAt.isAfter(report.createdAt)) ...[
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            icon: Icons.update_outlined,
            label: 'Last updated',
            value: formatReportTimestamp(report.updatedAt),
          ),
        ],
      ],
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
