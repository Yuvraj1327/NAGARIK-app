import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';

/// One pin's worth of data for the Nearby/Discovery map, as returned by
/// `GET /reports/markers` — deliberately a small subset of [Report]'s
/// fields (see `backend/app/schemas/report.py`'s `ReportMarkerResponse`
/// for why: a map may render dozens of pins, and a pin only needs a
/// location, a category/status for its icon/color, and enough identity to
/// open the full report on tap, not its description or images).
class ReportMarker {
  const ReportMarker({
    required this.id,
    required this.referenceId,
    required this.category,
    required this.status,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String referenceId;
  final ReportCategory category;
  final ReportStatus status;
  final String city;
  final double latitude;
  final double longitude;

  factory ReportMarker.fromJson(Map<String, dynamic> json) {
    return ReportMarker(
      id: json['id'] as String,
      referenceId: json['reference_id'] as String,
      category: ReportCategory.values.byName(json['category'] as String),
      status: _statusFromWire(json['status'] as String),
      city: json['city'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
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
}
