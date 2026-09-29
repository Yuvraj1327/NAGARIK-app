import 'package:flutter/material.dart';

/// The fixed set of civic-issue categories a report can belong to, per the
/// approved NAGARIK scope. Adding a category here is the only change
/// needed for it to show up everywhere (create-report step, feed cards,
/// filters) — nothing else should hardcode this list.
enum ReportCategory {
  road,
  streetlight,
  sanitation,
  water,
  electricity,
  safety,
  other;

  String get label => switch (this) {
        ReportCategory.road => 'Road',
        ReportCategory.streetlight => 'Streetlight',
        ReportCategory.sanitation => 'Sanitation',
        ReportCategory.water => 'Water',
        ReportCategory.electricity => 'Electricity',
        ReportCategory.safety => 'Safety',
        ReportCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        ReportCategory.road => Icons.add_road_outlined,
        ReportCategory.streetlight => Icons.lightbulb_outline,
        ReportCategory.sanitation => Icons.delete_outline,
        ReportCategory.water => Icons.water_drop_outlined,
        ReportCategory.electricity => Icons.bolt_outlined,
        ReportCategory.safety => Icons.shield_outlined,
        ReportCategory.other => Icons.report_gmailerrorred_outlined,
      };
}
