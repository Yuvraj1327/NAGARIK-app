import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';

/// The app's [TextTheme]. Deliberately uses the platform default font
/// (no `google_fonts` or custom font asset) to avoid an unnecessary
/// dependency — weight/size variation alone is enough for a clean,
/// citizen-friendly UI.
///
/// UI Polish upgrade: headings were bumped a notch heavier (w700/w800) and
/// given slightly tighter letter-spacing, and body copy was given a touch
/// more line-height — a "stronger hierarchy, easier to scan" pass per the
/// redesign brief ("make important text bold/semi-bold and highly
/// readable"), without touching any size that would reflow existing
/// layouts unpredictably or any color (the brand palette in
/// `app_colors.dart` is explicitly out of scope for that upgrade).
class AppTypography {
  AppTypography._();

  static const TextTheme textTheme = TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      height: 1.2,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.4,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.onPrimary,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
  );

  /// Same type scale as [textTheme], recolored for a dark background
  /// (`AppTheme.dark`). Kept as a fully separate table rather than a
  /// `.apply(color: ...)` call on [textTheme], since `labelLarge` (button
  /// label text) intentionally keeps `AppColors.onPrimary`, not the
  /// dark-mode body text color — buttons stay filled with `AppColors.primary`
  /// in both themes.
  static const TextTheme darkTextTheme = TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: 1.2,
      color: AppColors.darkTextPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      height: 1.2,
      color: AppColors.darkTextPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
      color: AppColors.darkTextPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.darkTextPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.4,
      color: AppColors.darkTextPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w500,
      color: AppColors.darkTextSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: AppColors.darkTextSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.onPrimary,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.darkTextSecondary,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.darkTextPrimary,
    ),
  );
}
