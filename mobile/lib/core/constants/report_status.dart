import 'package:nagarik/l10n/app_localizations.dart';

/// The fixed report-status lifecycle, per the approved NAGARIK scope.
/// Colors for each status live in `StatusBadge`
/// (shared/widgets/status_badge.dart), not here, so this file has no
/// Flutter dependency and can be reused by pure-Dart domain code later.
enum ReportStatus {
  submitted,
  inReview,
  resolved;

  String get label => switch (this) {
        ReportStatus.submitted => 'Submitted',
        ReportStatus.inReview => 'In Review',
        ReportStatus.resolved => 'Resolved',
      };
}

extension ReportStatusL10n on ReportStatus {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
        ReportStatus.submitted => l10n.repStatusSubmitted,
        ReportStatus.inReview => l10n.repStatusInReview,
        ReportStatus.resolved => l10n.repStatusResolved,
      };
}
