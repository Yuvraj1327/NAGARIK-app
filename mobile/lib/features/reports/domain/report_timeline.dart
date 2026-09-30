import 'package:nagarik/core/constants/report_status.dart';

/// Where a single timeline stage sits relative to a report's current
/// [ReportStatus]: already passed, the one the report is at right now, or
/// not reached yet.
enum TimelineStageState { completed, current, upcoming }

/// One labeled stop on a report's status timeline (Report Detail screen).
class TimelineStage {
  const TimelineStage({required this.label, required this.state});

  final String label;
  final TimelineStageState state;
}

/// Maps a report's current [ReportStatus] onto an ordered list of
/// [TimelineStage]s for `StatusTimeline` to render.
///
/// This only produces the three stages NAGARIK's backend actually tracks —
/// Report Submitted, Under Review, Resolved (see `ReportStatus` and
/// `backend/app/schemas/report.py`). An "Action Taken" stage between
/// "Under Review" and "Resolved" was part of the original design sketch for
/// this screen, but the backend has no status value for it (no
/// `action_taken` in `ReportStatus`/the database's `status` check
/// constraint) — a fourth stage on screen that no report could ever
/// actually reach would either sit permanently unlit (implying a step that
/// never happens) or have to be marked "complete" at the same moment as
/// Resolved with no real timestamp backing that (inventing history that
/// was never recorded). Neither is honest, so it's left out here.
///
/// What keeps this extensible rather than a dead end: everything below
/// this function — [TimelineStage], [TimelineStageState], and the
/// `StatusTimeline` widget — already works with an arbitrary ordered list
/// of stages. The day the backend adds a real intermediate status (e.g.
/// `action_taken`), this is the only function that needs to change to
/// insert it; no widget or screen needs to be touched.
List<TimelineStage> timelineStagesForStatus(ReportStatus status) {
  const labels = ['Report Submitted', 'Under Review', 'Resolved'];
  final currentIndex = switch (status) {
    ReportStatus.submitted => 0,
    ReportStatus.inReview => 1,
    ReportStatus.resolved => 2,
  };

  return [
    for (var index = 0; index < labels.length; index++)
      TimelineStage(
        label: labels[index],
        state: index < currentIndex
            ? TimelineStageState.completed
            : index == currentIndex
                ? TimelineStageState.current
                : TimelineStageState.upcoming,
      ),
  ];
}
