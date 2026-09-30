import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nagarik/core/constants/report_category.dart';
import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/features/reports/presentation/widgets/report_card.dart';
import 'package:nagarik/shared/widgets/status_badge.dart';

/// Step 9 hardening: widget coverage for the one card reused across the
/// feed, search results, "your reports", and the create-report review step
/// (report_card.dart) — a regression here would be visible almost
/// everywhere in the app.
void main() {
  testWidgets('ReportCard shows title, description, status, and location', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportCard(
            title: 'Road',
            description: 'Large pothole near the bus stop.',
            category: ReportCategory.road,
            status: ReportStatus.inReview,
            city: 'Pune',
            pinCode: '411001',
          ),
        ),
      ),
    );

    expect(find.text('Road'), findsOneWidget);
    expect(find.text('Large pothole near the bus stop.'), findsOneWidget);
    expect(find.text('Pune · 411001'), findsOneWidget);
    expect(find.text('In Review'), findsOneWidget);
  });

  testWidgets('ReportCard calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportCard(
            title: 'Water',
            description: 'Burst pipe flooding the street.',
            category: ReportCategory.water,
            status: ReportStatus.submitted,
            city: 'Mumbai',
            pinCode: '400001',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ReportCard));
    expect(tapped, isTrue);
  });

  testWidgets('ReportCard hides the footer row when no reference id or date is given',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportCard(
            title: 'Road',
            description: 'Large pothole near the bus stop.',
            category: ReportCategory.road,
            status: ReportStatus.submitted,
            city: 'Pune',
            pinCode: '411001',
          ),
        ),
      ),
    );

    expect(find.byType(Divider), findsNothing);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('ReportCard shows the reference id and date when given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportCard(
            title: 'Road',
            description: 'Large pothole near the bus stop.',
            category: ReportCategory.road,
            status: ReportStatus.submitted,
            city: 'Pune',
            pinCode: '411001',
            referenceId: 'NGR-2026-00001',
            date: DateTime(2026, 1, 15),
          ),
        ),
      ),
    );

    expect(find.text('NGR-2026-00001'), findsOneWidget);
    expect(find.text('15 Jan 2026'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('ReportCard shows a thumbnail when an image url is given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportCard(
            title: 'Road',
            description: 'Large pothole near the bus stop.',
            category: ReportCategory.road,
            status: ReportStatus.submitted,
            city: 'Pune',
            pinCode: '411001',
            imageUrl: 'https://signed.example/photo.jpg',
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('StatusBadge shows the right label for every status', (tester) async {
    for (final status in ReportStatus.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StatusBadge(status: status)),
        ),
      );
      expect(find.text(status.label), findsOneWidget);
    }
  });
}
