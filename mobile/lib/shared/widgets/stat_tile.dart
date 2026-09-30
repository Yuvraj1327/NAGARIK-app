import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_spacing.dart';

/// One number-over-label counter (e.g. "12 / Total Reports"). Used in a
/// [Row] of four on the Profile screen's stats strip; kept as its own
/// widget in case a later screen needs the same "big number, small label"
/// shape elsewhere.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color});

  final int value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(color: color),
        ),
        const SizedBox(height: AppSpacing.xs / 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
          maxLines: 2,
        ),
      ],
    );
  }
}
