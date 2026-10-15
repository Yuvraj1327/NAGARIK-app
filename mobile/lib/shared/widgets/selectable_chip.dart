import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/shared/widgets/animations/pressable_scale.dart';

/// Rounded filter chip used by Search & Discover and My Reports. Selected
/// state is a solid brand-blue fill (optionally with a leading check, as in
/// the My Reports reference); unselected is a white outlined pill.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.showCheckWhenSelected = false,
    this.isLoading = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool showCheckWhenSelected;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = selected
        ? AppColors.onPrimary
        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);
    final background =
        selected ? AppColors.primary : (isDark ? AppColors.darkSurface : AppColors.surface);
    final borderColor =
        selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border);

    final leading = isLoading
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : (selected && showCheckWhenSelected
            ? Icon(Icons.check_rounded, size: 18, color: foreground)
            : (icon != null ? Icon(icon, size: 18, color: foreground) : null));

    return PressableScale(
      enabled: onTap != null,
      child: Material(
        color: background,
        shape: StadiumBorder(side: BorderSide(color: borderColor)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 6)],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
