import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/reports/domain/report_marker.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/error_view.dart';
import 'package:nagarik/shared/widgets/loading_view.dart';
import 'package:nagarik/shared/widgets/status_badge.dart';

/// The compact report preview shown when a map marker is tapped, plus a way
/// to open the full Report Detail screen.
///
/// Fetches the full report lazily, on tap, via the same `reportByIdProvider`
/// the Report Detail screen already uses — not a new endpoint, and nothing
/// is fetched for the markers the user never taps. That's what keeps the
/// map's initial load lean (see `ReportMarker`'s doc comment for why the
/// marker list itself carries no description or images) while a tap still
/// shows real detail, not a dead end.
class ReportMarkerPreviewSheet extends ConsumerWidget {
  const ReportMarkerPreviewSheet({super.key, required this.marker});

  final ReportMarker marker;

  static Future<void> show(BuildContext context, ReportMarker marker) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => ReportMarkerPreviewSheet(marker: marker),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportByIdProvider(marker.id));
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: reportAsync.when(
          loading: () => const SizedBox(height: 160, child: LoadingView()),
          error: (error, stackTrace) => SizedBox(
            height: 160,
            child: ErrorView.forError(
              error,
              onRetry: () => ref.invalidate(reportByIdProvider(marker.id)),
              fallbackMessage: 'Could not load this report.',
            ),
          ),
          data: (report) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(report.category.icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(report.category.label, style: textTheme.titleMedium),
                  ),
                  StatusBadge(status: report.status),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                report.referenceId,
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                report.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text('${report.city} · ${report.pinCode}', style: textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'View Full Details',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/report/${report.id}');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
