import 'package:flutter/material.dart';

import 'package:nagarik/shared/widgets/animations/pressable_scale.dart';

enum AppButtonVariant { primary, secondary, outlined, text }

/// The one button widget the whole app should use, so every screen gets
/// the same shapes/heights/loading behavior for free.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spinnerColor = variant == AppButtonVariant.primary ? scheme.onPrimary : scheme.primary;

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: spinnerColor),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final onTap = isLoading ? null : onPressed;

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(onPressed: onTap, child: child),
      AppButtonVariant.secondary => FilledButton.tonal(onPressed: onTap, child: child),
      AppButtonVariant.outlined => OutlinedButton(onPressed: onTap, child: child),
      AppButtonVariant.text => TextButton(onPressed: onTap, child: child),
    };

    final sized = expand ? SizedBox(width: double.infinity, height: 48, child: button) : button;

    // UI Polish upgrade: small press-down scale feedback, disabled while
    // loading/disabled (nothing to give feedback for — `onTap` is already
    // null in that case).
    return PressableScale(enabled: onTap != null, child: sized);
  }
}
