import 'package:flutter/material.dart';

import 'package:nagarik/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    return Container(
      color: context.tintColor.withOpacity(0.4),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, color: context.accentColor),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.repMapUnavailable,
            style: textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          if (!compact)
            Text(
              l10n.repMapNotConfigured,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
