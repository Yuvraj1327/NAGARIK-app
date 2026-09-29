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
