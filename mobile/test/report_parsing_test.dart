import 'package:flutter_test/flutter_test.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/domain/reports_page.dart';

/// Step 9 hardening: pure-Dart coverage of the wire-format parsing that
/// every screen depends on (Report.fromJson / ReportsPage.fromJson /
/// Report.statusToWire). These don't need a widget pump — they're plain
/// JSON-to-object mapping, and a mistake here (a wrong key, a status that
/// doesn't round-trip) would silently break every screen that shows a
/// report, so it's worth testing in isolation from the UI.
void main() {
  Map<String, dynamic> reportJson({
    String status = 'submitted',
    List<String> imagePaths = const [],
    List<String>? imageUrls,
    double? latitude,
    double? longitude,
  }) {
    return {
      'id': 'report-1',
      'user_id': 'user-123',
      'category': 'road',
      'description': 'Large pothole near the bus stop.',
      'city': 'Pune',
      'pin_code': '411001',
      'latitude': latitude,
      'longitude': longitude,
      'image_paths': imagePaths,
      'image_urls': imageUrls,
      'status': status,
      'created_at': '2026-01-15T10:30:00+00:00',
      'updated_at': '2026-01-15T10:30:00+00:00',
    };
  }

  group('Report.fromJson', () {
    test('parses a full report response', () {
      final report = Report.fromJson(
        reportJson(
          imagePaths: ['user-123/a.jpg'],
          imageUrls: ['https://signed.example/a.jpg'],
          latitude: 18.5204,
          longitude: 73.8567,
        ),
      );

      expect(report.id, 'report-1');
      expect(report.userId, 'user-123');
      expect(report.category, ReportCategory.road);
      expect(report.description, 'Large pothole near the bus stop.');
      expect(report.city, 'Pune');
      expect(report.pinCode, '411001');
      expect(report.latitude, 18.5204);
      expect(report.longitude, 73.8567);
      expect(report.imagePaths, ['user-123/a.jpg']);
      expect(report.imageUrls, ['https://signed.example/a.jpg']);
      expect(report.status, ReportStatus.submitted);
    });

    test('treats a missing latitude/longitude as null, not a crash', () {
      final report = Report.fromJson(reportJson());
      expect(report.latitude, isNull);
      expect(report.longitude, isNull);
    });

    test('defaults image_urls to an empty list when the key is missing', () {
      final json = reportJson()..remove('image_urls');
      final report = Report.fromJson(json);
      expect(report.imageUrls, isEmpty);
    });

    test('maps every wire status value to its enum', () {
      expect(Report.fromJson(reportJson(status: 'submitted')).status, ReportStatus.submitted);
      expect(Report.fromJson(reportJson(status: 'in_review')).status, ReportStatus.inReview);
      expect(Report.fromJson(reportJson(status: 'resolved')).status, ReportStatus.resolved);
    });

    test('throws a clear error for an unknown status rather than parsing wrong', () {
      expect(
        () => Report.fromJson(reportJson(status: 'archived')),
        throwsFormatException,
      );
    });
  });

  group('Report.statusToWire', () {
    test('round-trips every status through wire format and back', () {
      for (final status in ReportStatus.values) {
        final wire = Report.statusToWire(status);
        final parsed = Report.fromJson(reportJson(status: wire)).status;
        expect(parsed, status, reason: 'status $status did not round-trip via "$wire"');
      }
    });
  });

  group('ReportsPage.fromJson', () {
    test('parses items and pagination metadata', () {
      final page = ReportsPage.fromJson({
        'items': [reportJson(), reportJson()],
        'total': 5,
        'limit': 2,
        'offset': 0,
      });

      expect(page.items, hasLength(2));
      expect(page.total, 5);
      expect(page.limit, 2);
      expect(page.offset, 0);
      expect(page.hasMore, isTrue);
    });

    test('hasMore is false once every item has been fetched', () {
      final page = ReportsPage.fromJson({
        'items': [reportJson()],
        'total': 1,
        'limit': 20,
        'offset': 0,
      });

      expect(page.hasMore, isFalse);
    });

    test('parses an empty page', () {
      final page = ReportsPage.fromJson({
        'items': <dynamic>[],
        'total': 0,
        'limit': 20,
        'offset': 0,
      });

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });
}
