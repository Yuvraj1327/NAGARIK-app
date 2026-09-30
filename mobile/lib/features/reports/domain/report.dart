import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';

/// A submitted report, exactly as the backend returns it — from creating one
/// (`POST /reports`, Step 5/6) or from fetching one (`GET /reports`,
/// `GET /reports/:id`, Step 7/8).
class Report {
  const Report({
    required this.id,
    required this.referenceId,
    required this.userId,
    required this.category,
    required this.description,
    required this.city,
    required this.pinCode,
    required this.imagePaths,
    required this.imageUrls,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.isSaved = false,
  });

  final String id;

  /// Stable, human-readable reference (e.g. "NGR-2026-00001") — see
  /// `backend/migrations/0003_report_reference_id.sql`. Assigned once by
  /// the backend when the report is created and never changed afterwards,
  /// so this is what's shown on report cards and the report detail screen
  /// for a citizen to identify or quote a report; [id] (an opaque UUID)
  /// stays purely an API/navigation detail.
  final String referenceId;
  final String userId;
  final ReportCategory category;
  final String description;
  final String city;
  final String pinCode;
  final double? latitude;
  final double? longitude;
  final List<String> imagePaths;

  /// Freshly signed Storage URLs for [imagePaths] (Step 7) — the bucket is
  /// private, so these (not [imagePaths]) are what the UI should actually
  /// load images from. Short-lived; re-fetch the report to refresh them.
  final List<String> imageUrls;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether the signed-in caller has bookmarked this report (Report
  /// Sharing & Saved Reports upgrade) — never anyone else's saved state,
  /// just the caller's own. `false` for an anonymous request or wherever
  /// the backend doesn't bother computing it (a plain browse/search list;
  /// see `ReportResponse.is_saved`'s docstring on the backend). Always
  /// `true` for an item returned by `GET /reports/saved`.
  final bool isSaved;

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      referenceId: json['reference_id'] as String,
      userId: json['user_id'] as String,
      category: ReportCategory.values.byName(json['category'] as String),
      description: json['description'] as String,
      city: json['city'] as String,
      pinCode: json['pin_code'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      imagePaths: (json['image_paths'] as List<dynamic>).cast<String>(),
      imageUrls: (json['image_urls'] as List<dynamic>? ?? const []).cast<String>(),
      status: _statusFromWire(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isSaved: json['is_saved'] as bool? ?? false,
    );
  }

  static ReportStatus _statusFromWire(String value) {
    switch (value) {
      case 'submitted':
        return ReportStatus.submitted;
      case 'in_review':
        return ReportStatus.inReview;
      case 'resolved':
        return ReportStatus.resolved;
      default:
        throw FormatException('Unknown report status from backend: $value');
    }
  }

  /// The inverse of [_statusFromWire] — used by [ReportsRepository] to send
  /// a status filter back to the backend in its wire format.
  static String statusToWire(ReportStatus status) {
    switch (status) {
      case ReportStatus.submitted:
        return 'submitted';
      case ReportStatus.inReview:
        return 'in_review';
      case ReportStatus.resolved:
        return 'resolved';
    }
  }
}
