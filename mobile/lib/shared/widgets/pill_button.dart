import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/shared/widgets/animations/pressable_scale.dart';

enum PillButtonVariant { primary, outlined, soft }

/// Full-width, fully rounded 56px button used by the redesigned onboarding
/// and Report Issue flows (UI recreation from the supplied reference
/// screens). Deliberately separate from [AppButton] (8px radius, 48px) so
/// every other screen in the app is untouched.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillButtonVariant.primary,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final onTap = isLoading ? null : onPressed;
    final isPrimary = variant == PillButtonVariant.primary;

    final foreground = switch (variant) {
      PillButtonVariant.primary => AppColors.onPrimary,
      PillButtonVariant.outlined => AppColors.textPrimary,
      PillButtonVariant.soft => AppColors.textPrimary,
    };
    final background = switch (variant) {
      PillButtonVariant.primary => AppColors.primary,
      PillButtonVariant.outlined => AppColors.surface,
      PillButtonVariant.soft => AppColors.primaryLight,
    };

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: foreground),
          )
        : Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: foreground),
          );

    return PressableScale(
      enabled: onTap != null,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: isPrimary ? AppColors.primary.withOpacity(0.5) : background,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: StadiumBorder(
              side: variant == PillButtonVariant.outlined
                  ? const BorderSide(color: AppColors.border, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
