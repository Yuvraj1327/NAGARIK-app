import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/reports/domain/report_timeline.dart';

/// A vertical progress timeline for a report's status (Report Detail
/// screen): a dot per stage connected by a line, with completed stages
/// checked off, the current stage highlighted, and later stages shown
/// muted/outlined. Driven entirely by [stages], so it renders whatever
/// ordered list of [TimelineStage]s it's given — see
/// `report_timeline.dart`'s `timelineStagesForStatus` for why that list
/// currently has three entries rather than the four in the original design
/// sketch.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.stages});

  final List<TimelineStage> stages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < stages.length; index++)
          _TimelineRow(
            stage: stages[index],
            isLast: index == stages.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.stage, required this.isLast});

  final TimelineStage stage;
  final bool isLast;

  static const double _dotSize = 24;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.darkTextDisabled : AppColors.textDisabled;
    final activeColor = AppColors.primary;
    final isReached = stage.state != TimelineStageState.upcoming;
    final lineColor = stage.state == TimelineStageState.completed ? activeColor : mutedColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _Dot(state: stage.state, size: _dotSize, activeColor: activeColor, mutedColor: mutedColor),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: lineColor),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg, top: 2),
              child: Text(
                stage.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: stage.state == TimelineStageState.current
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isReached
                          ? (stage.state == TimelineStageState.current
                              ? activeColor
                              : Theme.of(context).textTheme.bodyMedium?.color)
                          : mutedColor,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.state,
    required this.size,
    required this.activeColor,
    required this.mutedColor,
  });

  final TimelineStageState state;
  final double size;
  final Color activeColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case TimelineStageState.completed:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 15, color: Colors.white),
        );
      case TimelineStageState.current:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: activeColor,
            shape: BoxShape.circle,
            border: Border.all(color: activeColor.withAlpha(70), width: 4),
          ),
        );
      case TimelineStageState.upcoming:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: mutedColor, width: 2),
          ),
        );
    }
  }
}
