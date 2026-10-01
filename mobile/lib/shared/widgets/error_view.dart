import 'package:flutter/material.dart';

import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/shared/widgets/animations/fade_slide_in.dart';
import 'package:nagarik/shared/widgets/app_button.dart';

/// Standard full-area error state: an icon, a message, and an optional
/// "Retry" action. Used whenever an API/Supabase call fails.
///
/// [icon] defaults to a generic error glyph; [ErrorView.forError] (Final
/// Feature Polish upgrade) picks a more specific one — a "no connection"
/// state for a request that never reached the server versus a generic one
/// for a server-returned error — so the two read as distinct, correctly
/// diagnosed states instead of the same generic message either way.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  /// Builds the message/icon from [error] itself: a network failure (no
  /// response reached the server at all — see [ApiException.isNetworkError])
  /// gets a "check your connection" state; any other [ApiException] shows
  /// its own server-provided message; anything else falls back to
  /// [fallbackMessage].
  factory ErrorView.forError(
    Object error, {
    Key? key,
    VoidCallback? onRetry,
    String fallbackMessage = 'Something went wrong. Please try again.',
  }) {
    if (error is ApiException && error.isNetworkError) {
      return ErrorView(
        key: key,
        icon: Icons.wifi_off_outlined,
        message: "Can't reach NAGARIK. Check your internet connection and try again.",
        onRetry: onRetry,
      );
    }
    return ErrorView(
      key: key,
      icon: Icons.cloud_off_outlined,
      message: error is ApiException ? error.message : fallbackMessage,
      onRetry: onRetry,
    );
  }

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 32, color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppButton(label: 'Retry', onPressed: onRetry, expand: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
