import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/features/discovery/presentation/providers/discovery_providers.dart';

/// "📍 Bhopal" — the Home screen's current-location indicator, covering
/// every state `homeLocationProvider` can be in: loading, resolved (with
/// or without a city name), and every location failure mode (permission
/// denied, denied forever, service disabled, unavailable) with a Retry
/// action. Failing to resolve a location never blocks the rest of Home —
/// this widget only affects its own row.
class LocationIndicator extends ConsumerWidget {
  const LocationIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(homeLocationProvider);

    return locationAsync.when(
      loading: () => const _IndicatorRow(
        icon: Icons.location_searching,
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => _IndicatorRow(
        icon: Icons.location_off_outlined,
        color: AppColors.textSecondary,
        child: Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(homeLocationProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (location) => _IndicatorRow(
        icon: Icons.location_on,
        color: AppColors.primary,
        child: Flexible(
          child: Text(
            location.city ??
                '${location.position.latitude.toStringAsFixed(3)}, '
                    '${location.position.longitude.toStringAsFixed(3)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({required this.icon, required this.child, this.color});

  final IconData icon;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        child,
      ],
    );
  }
}
