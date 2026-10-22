import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/app_button.dart';

/// Standard full-area empty state: an icon, a title, an optional message,
/// and an optional action (e.g. "Report an issue").
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required String this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : _kind = null;

  final IconData icon;

  /// Null only for the named constructors, which resolve localized copy in
  /// [build] via [_kind].
  final String? title;
  final _EmptyKind? _kind;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// "You haven't submitted anything yet" (My Reports, Home's Recent
  /// Reports section when the whole feed is empty) — one consistent copy
  /// instead of each screen writing its own wording for the same situation
  /// (Final Feature Polish upgrade).
  const EmptyView.noReports({super.key, this.actionLabel, this.onAction})
      : icon = Icons.assignment_outlined,
        title = null,
        message = null,
        _kind = _EmptyKind.noReports;

  /// Saved Reports, empty.
  const EmptyView.noSavedReports({super.key})
      : icon = Icons.bookmark_border,
        title = null,
        message = null,
        _kind = _EmptyKind.noSavedReports,
        actionLabel = null,
        onAction = null;

  /// Home's "Nearby Issues" section when the device's location resolved but
  /// no report was found within range.
  const EmptyView.noNearbyReports({super.key})
      : icon = Icons.explore_off_outlined,
        title = null,
        message = null,
        _kind = _EmptyKind.noNearbyReports,
        actionLabel = null,
        onAction = null;

  /// Search, after a search or filter combination matches nothing.
  const EmptyView.searchNoResults({super.key})
      : icon = Icons.search_off_outlined,
        title = null,
        message = null,
        _kind = _EmptyKind.searchNoResults,
        actionLabel = null,
        onAction = null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final (String resolvedTitle, String? resolvedMessage) = switch (_kind) {
      _EmptyKind.noReports => (l10n.commonEmptyNoReportsTitle, l10n.commonEmptyNoReportsMessage),
      _EmptyKind.noSavedReports => (
          l10n.commonEmptyNoSavedTitle,
          l10n.commonEmptyNoSavedMessage,
        ),
      _EmptyKind.noNearbyReports => (
          l10n.commonEmptyNoNearbyTitle,
          l10n.commonEmptyNoNearbyMessage,
        ),
      _EmptyKind.searchNoResults => (
          l10n.commonEmptyNoMatchTitle,
          l10n.commonEmptyNoMatchMessage,
        ),
      null => (title!, message),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkBorder : AppColors.border).withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 36, color: AppColors.textDisabled),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                resolvedTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (resolvedMessage != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  resolvedMessage,
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
      ),
    );
  }
}

enum _EmptyKind { noReports, noSavedReports, noNearbyReports, searchNoResults }
