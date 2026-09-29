import 'package:image_picker/image_picker.dart';

import 'package:nagarik/core/constants/report_category.dart';

/// The in-progress state of a report the user is creating, held by
/// `CreateReportScreen` across its steps.
///
/// This is intentionally a plain mutable holder, not the final `Report`
/// domain entity (`report.dart`, Step 5) — that one represents what the
/// backend returns after a report has actually been created.
class ReportDraft {
  ReportCategory? category;
  String description = '';
  String city = '';
  String pinCode = '';

  /// Set by the "Use current location" button (Step 6). Null means no
  /// coordinates were captured — location is optional, not required, so a
  /// report can still be submitted without it.
  double? latitude;
  double? longitude;

  /// Picked from the gallery or camera (Step 6). Capped at
  /// [ReportsRepository.maxImages] in the UI before submission is attempted.
  List<XFile> images = [];
}
