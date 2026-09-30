import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/shared/widgets/app_button.dart';

/// Standard full-area empty state: an icon, a title, an optional message,
/// and an optional action (e.g. "Report an issue").
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// "You haven't submitted anything yet" (My Reports, Home's Recent
  /// Reports section when the whole feed is empty) — one consistent copy
  /// instead of each screen writing its own wording for the same situation
  /// (Final Feature Polish upgrade).
  const EmptyView.noReports({super.key, this.actionLabel, this.onAction})
      : icon = Icons.assignment_outlined,
        title = 'No reports yet',
        message = 'Reports submitted here will show up in this list.';

  /// Saved Reports, empty.
  const EmptyView.noSavedReports({super.key})
      : icon = Icons.bookmark_border,
        title = 'No saved reports yet',
        message = 'Tap the bookmark icon on a report to save it here for later.',
        actionLabel = null,
        onAction = null;

  /// Home's "Nearby Issues" section when the device's location resolved but
  /// no report was found within range.
  const EmptyView.noNearbyReports({super.key})
      : icon = Icons.explore_off_outlined,
        title = 'No civic issues nearby',
        message = 'Nothing has been reported near you recently.',
        actionLabel = null,
        onAction = null;

  /// Search, after a search or filter combination matches nothing.
  const EmptyView.searchNoResults({super.key})
      : icon = Icons.search_off_outlined,
        title = 'No matching reports',
        message = 'Try a different keyword or loosen your filters.',
        actionLabel = null,
        onAction = null;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textDisabled),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}
