import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/shared/widgets/logo.dart';

/// The one app bar the whole app should use for its main screens, so
/// title style and height stay consistent (driven by `AppTheme`'s
/// `appBarTheme`).
///
/// [showLogo] (Official Logo upgrade) prepends the small NAGARIK brand mark
/// before the title — used on the Home app bar, the app's main "header",
/// so the logo appears there without every other screen (Search, Edit
/// Profile, Settings, ...) repeating it next to titles that are already
/// screen-specific.
class PrimaryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrimaryAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.showLogo = false,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: showLogo
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Logo(size: 28),
                const SizedBox(width: AppSpacing.sm),
                Text(title),
              ],
            )
          : Text(title),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
