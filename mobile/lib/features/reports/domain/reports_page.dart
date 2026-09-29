import 'package:nagarik/features/reports/domain/report.dart';

/// One page of `GET /reports` results (Step 7/8): the reports themselves,
/// plus enough pagination metadata to know whether there's more to load.
class ReportsPage {
  const ReportsPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<Report> items;
  final int total;
  final int limit;
  final int offset;

  /// Whether requesting the next `offset` would return more reports.
  bool get hasMore => offset + items.length < total;

  factory ReportsPage.fromJson(Map<String, dynamic> json) {
    return ReportsPage(
      items: (json['items'] as List<dynamic>)
          .map((item) => Report.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}
