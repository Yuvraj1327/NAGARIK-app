import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/shared/widgets/animations/pressable_scale.dart';

/// The one card container the whole app should use. Applies its border/
/// radius/elevation directly via `Card`'s own constructor parameters
/// (rather than `ThemeData.cardTheme`, whose type has shifted across
/// recent Flutter versions) so it stays stable regardless of exact
/// Flutter patch version.
///
/// Its surface/border color branches on `Theme.of(context).brightness`
/// instead of reading `Theme.of(context).colorScheme.surface` directly —
/// deliberately, so light mode's exact existing appearance (pure white,
/// `AppColors.border`) is untouched pixel-for-pixel by adding dark mode
/// support (Material 3's seeded `colorScheme.surface` is a faint tint, not
/// pure white, and would have subtly shifted every card already in the app).
///
/// UI Polish upgrade: gained a soft drop shadow (a "premium" elevated
/// surface instead of a flat bordered box) and, when [onTap] is set, a
/// small [PressableScale] press-down — both purely visual, the border/
/// radius/colors above are untouched.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: child,
    );

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.28) : const Color(0x0F12213A),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Card(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: onTap != null ? InkWell(onTap: onTap, child: content) : content,
      ),
    );

    return PressableScale(enabled: onTap != null, child: card);
  }
}
