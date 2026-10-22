import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';

/// Numbered step header for the Report Issue flow (Type / Photo / Place /
/// Details / Review): a filled circle with a check for finished steps, a
/// filled circle with the number for the current one, and an outlined
/// circle for upcoming ones, each with its label underneath — recreated
/// from the supplied reference screens.
class ReportStepper extends StatelessWidget {
  const ReportStepper({super.key, required this.labels, required this.currentStep});

  final List<String> labels;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= currentStep ? AppColors.primary : context.surfaceColor,
                    border: Border.all(
                      color: i <= currentStep ? AppColors.primary : context.borderColor,
                      width: 2,
                    ),
                  ),
                  child: i < currentStep
                      ? const Icon(Icons.check, size: 18, color: AppColors.onPrimary)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: i == currentStep ? AppColors.onPrimary : context.textSecondaryColor,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: i == currentStep ? FontWeight.w800 : FontWeight.w500,
                    color: i <= currentStep ? context.accentColor : context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
