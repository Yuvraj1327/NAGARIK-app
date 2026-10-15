import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';

/// Shown in place of a map when Google Maps can't load (web without a valid
/// `GOOGLE_MAPS_WEB_API_KEY`). Everything else keeps working without it.
class MapUnavailableView extends StatelessWidget {
  const MapUnavailableView({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      color: AppColors.primaryLight.withOpacity(0.4),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, color: AppColors.primary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Map unavailable',
            style: textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          if (!compact)
            Text(
              'Google Maps is not configured for this build.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
