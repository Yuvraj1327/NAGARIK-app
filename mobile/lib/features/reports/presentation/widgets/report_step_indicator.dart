import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';

/// Report Issue redesign: a row of pill-shaped progress segments — one per
/// step of the Type / Photo / Place / Details / Review flow
/// (`create_report_screen.dart`) — so the person always sees where they are
/// and how much is left, the same role the reference screenshots' dash
/// progress bar plays in their onboarding. Deliberately a plain animated
/// dash row rather than numbered circles, to stay compact above each
/// step's own title; every segment up to and including [currentStep] fills
/// in `AppColors.primary`, the rest stay `AppColors.border`.
///
/// Generic enough (just [stepCount]/[currentStep], nothing Report-specific
/// in its logic) that the Onboarding redesign's `OnboardingScreen` reuses
/// it as-is for its own 7 numbered steps, rather than building a near-
/// identical widget a second time.
class ReportStepIndicator extends StatelessWidget {
  const ReportStepIndicator({super.key, required this.stepCount, required this.currentStep});

  final int stepCount;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stepCount; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 4,
              decoration: BoxDecoration(
                color: i <= currentStep ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          if (i != stepCount - 1) const SizedBox(width: AppSpacing.xs),
        ],
      ],
    );
  }
}
