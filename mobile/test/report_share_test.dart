import 'package:flutter_test/flutter_test.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/features/reports/domain/report.dart';
import 'package:nagarik/features/reports/domain/report_share.dart';

/// Report Sharing & Saved Reports upgrade: `buildReportShareText` is a pure
/// function (no Flutter widget involved), so its content — and, just as
/// importantly, what it deliberately leaves out — is covered directly
/// rather than through a widget pump.
void main() {
  Report makeReport({String? description}) {
    final now = DateTime(2026, 1, 15);
    return Report(
      id: 'report-uuid-1',
      referenceId: 'NGR-2026-00042',
      userId: 'user-uuid-should-never-appear',
      category: ReportCategory.road,
      description: description ?? 'A large pothole outside the main market.',
      city: 'Pune',
      pinCode: '411001',
      imagePaths: const [],
      imageUrls: const [],
      status: ReportStatus.inReview,
      createdAt: now,
      updatedAt: now,
      latitude: 18.52041234,
      longitude: 73.85671234,
    );
  }

  test('includes NAGARIK, reference id, category, description, city, and status', () {
    final text = buildReportShareText(makeReport());

    expect(text, contains('NAGARIK'));
    expect(text, contains('NGR-2026-00042'));
    expect(text, contains('Road'));
    expect(text, contains('A large pothole outside the main market.'));
    expect(text, contains('Pune'));
    expect(text, contains('In Review'));
  });

  test('never includes the user id or exact GPS coordinates', () {
    final text = buildReportShareText(makeReport());

    expect(text, isNot(contains('user-uuid-should-never-appear')));
    expect(text, isNot(contains('18.52041234')));
    expect(text, isNot(contains('73.85671234')));
  });

  test('truncates a long description with an ellipsis rather than sharing it in full', () {
    final longDescription = 'x' * 500;
    final text = buildReportShareText(makeReport(description: longDescription));

    expect(text, isNot(contains(longDescription)));
    expect(text, contains('…'));
  });
}
