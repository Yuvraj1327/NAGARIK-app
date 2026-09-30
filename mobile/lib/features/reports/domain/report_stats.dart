/// Per-status counts of the signed-in caller's own reports, as returned by
/// `GET /reports/stats` — backs the Profile screen's stat tiles.
class ReportStats {
  const ReportStats({
    required this.total,
    required this.submitted,
    required this.inReview,
    required this.resolved,
  });

  final int total;
  final int submitted;
  final int inReview;
  final int resolved;

  static const zero = ReportStats(total: 0, submitted: 0, inReview: 0, resolved: 0);

  factory ReportStats.fromJson(Map<String, dynamic> json) {
    return ReportStats(
      total: json['total'] as int,
      submitted: json['submitted'] as int,
      inReview: json['in_review'] as int,
      resolved: json['resolved'] as int,
    );
  }
}
