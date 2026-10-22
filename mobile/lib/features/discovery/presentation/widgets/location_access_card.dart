import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:nagarik/features/reports/data/location_service.dart';
import 'package:nagarik/features/reports/presentation/providers/reports_providers.dart';
import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/shared/widgets/app_card.dart';

/// Home's "Location access" card. Driven entirely by the real
/// `homeLocationProvider`:
/// - while resolving: a spinner;
/// - on failure: the actual reason plus an "Enable" button that re-asks for
///   permission, or — when the OS will no longer show the prompt (denied
///   forever, or location services off) — opens the right OS settings page;
/// - on success: the resolved city, with a refresh action.
class LocationAccessCard extends ConsumerWidget {
  const LocationAccessCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locationAsync = ref.watch(homeLocationProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: locationAsync.when(
        loading: () => _CardRow(
          icon: Icons.location_searching_rounded,
          title: l10n.homeLocFinding,
          subtitle: l10n.homeLocLooking,
          trailing: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, stackTrace) {
          final exception = error is LocationException ? error : null;
          final needsSettings =
              exception != null && (exception.needsAppSettings || exception.needsLocationServices);
          return _CardRow(
            icon: Icons.location_on_outlined,
            title: l10n.homeLocAccess,
            subtitle: exception?.message ?? l10n.homeLocEnablePrompt,
            trailing: _CardButton(
              label: needsSettings ? l10n.homeLocSettings : l10n.homeLocEnable,
              onPressed: () {
                final service = ref.read(locationServiceProvider);
                if (exception != null && exception.needsAppSettings) {
                  service.openAppSettings();
                } else if (exception != null && exception.needsLocationServices) {
                  service.openLocationSettings();
                } else {
                  ref.invalidate(homeLocationProvider);
                }
              },
            ),
          );
        },
        data: (location) => _CardRow(
          icon: Icons.location_on_rounded,
          title: location.city ??
              '${location.position.latitude.toStringAsFixed(3)}, '
                  '${location.position.longitude.toStringAsFixed(3)}',
          subtitle: l10n.homeLocShowing,
          trailing: IconButton(
            tooltip: l10n.homeLocRefresh,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: () => ref.invalidate(homeLocationProvider),
          ),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        trailing,
      ],
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}
