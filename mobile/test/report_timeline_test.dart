import 'package:flutter_test/flutter_test.dart';

import 'package:nagarik/core/constants/report_status.dart';
import 'package:nagarik/features/reports/domain/report_timeline.dart';

/// My Reports & Report Tracking upgrade: pure-Dart coverage of
/// `timelineStagesForStatus`, the mapping the Report Detail screen's
/// `StatusTimeline` widget is driven by. No widget pump needed — this is
/// plain data mapping, and a wrong mapping here would silently mislabel a
/// report's progress (e.g. showing "Resolved" as still in progress).
void main() {
  group('timelineStagesForStatus', () {
    test('submitted: only the first stage is current, the rest are upcoming', () {
      final stages = timelineStagesForStatus(ReportStatus.submitted);

      expect(stages, hasLength(3));
      expect(stages[0].label, 'Report Submitted');
      expect(stages[0].state, TimelineStageState.current);
      expect(stages[1].state, TimelineStageState.upcoming);
      expect(stages[2].state, TimelineStageState.upcoming);
    });

    test('inReview: the first stage is completed, the second is current', () {
      final stages = timelineStagesForStatus(ReportStatus.inReview);

      expect(stages[0].label, 'Report Submitted');
      expect(stages[0].state, TimelineStageState.completed);
      expect(stages[1].label, 'Under Review');
      expect(stages[1].state, TimelineStageState.current);
      expect(stages[2].label, 'Resolved');
      expect(stages[2].state, TimelineStageState.upcoming);
    });

    test('resolved: every earlier stage is completed and the last is current', () {
      final stages = timelineStagesForStatus(ReportStatus.resolved);

      expect(stages[0].state, TimelineStageState.completed);
      expect(stages[1].state, TimelineStageState.completed);
      expect(stages[2].label, 'Resolved');
      expect(stages[2].state, TimelineStageState.current);
    });

    test('always returns exactly the three stages the backend actually tracks', () {
      for (final status in ReportStatus.values) {
        final labels = timelineStagesForStatus(status).map((stage) => stage.label).toList();
        expect(labels, ['Report Submitted', 'Under Review', 'Resolved']);
      }
    });

    test('exactly one stage is current for every status', () {
      for (final status in ReportStatus.values) {
        final currentCount = timelineStagesForStatus(status)
            .where((stage) => stage.state == TimelineStageState.current)
            .length;
        expect(currentCount, 1, reason: 'status $status should have exactly one current stage');
      }
    });
  });
}
