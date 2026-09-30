import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';

/// One tappable row inside a [SettingsSection] — an icon, a title, an
/// optional subtitle, and a trailing chevron (or a custom [trailing]
/// widget, e.g. a checkmark for the selected theme option). Used by both
/// the Profile screen's grouped lists and the Settings screen.
class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Red icon/title (e.g. "Logout") instead of the normal primary/text
  /// colors — a lighter-weight signal than a full confirmation dialog on
  /// its own, but this project still confirms destructive actions with a
  /// dialog before calling through (see `ProfileScreen`/`SettingsScreen`).
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = isDestructive ? AppColors.error : theme.textTheme.bodyLarge?.color;
    final iconColor = isDestructive ? AppColors.error : theme.colorScheme.primary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(color: titleColor, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null ? Text(subtitle!, style: theme.textTheme.bodySmall) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
