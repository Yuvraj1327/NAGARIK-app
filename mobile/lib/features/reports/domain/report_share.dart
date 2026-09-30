import 'package:nagarik/features/reports/domain/report.dart';

/// Builds the plain-text message shared from Report Detail's "Share"
/// action (Report Sharing & Saved Reports upgrade).
///
/// Deliberately limited to: the NAGARIK name, the report's reference id,
/// category, a trimmed description, its city, and its current status —
/// nothing else. In particular, this never includes [Report.userId], exact
/// GPS coordinates, or anything else that could identify or locate who
/// filed the report; "city" is already a field the reporter chose to make
/// public on submission (Step 5/6), same as every report card already
/// shows. Kept as a pure function (no Flutter import) so it's covered by a
/// plain-Dart unit test rather than a widget test.
String buildReportShareText(Report report) {
  const maxDescriptionLength = 160;
  final description = report.description.trim();
  final shortDescription = description.length > maxDescriptionLength
      ? '${description.substring(0, maxDescriptionLength).trimRight()}…'
      : description;

  return 'NAGARIK Civic Report\n'
      'Report ID: ${report.referenceId}\n'
      'Category: ${report.category.label}\n'
      '$shortDescription\n'
      'Location: ${report.city}\n'
      'Status: ${report.status.label}';
}
