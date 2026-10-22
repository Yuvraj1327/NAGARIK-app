import 'package:flutter/material.dart';

/// Centralized color palette. Nothing outside this class should hardcode a
/// `Color(0x...)` literal for anything that appears more than once.
///
/// The palette is derived from the official NAGARIK logo
/// (assets/images/nagarik_logo.png): royal/navy blue shield (~#1A4BA3),
/// near-black outline, orange dot (~#E8853A) and white check mark. Blue is
/// the primary brand color, orange is the single complementary accent, and
/// everything else (surfaces, text, borders) is a navy-tinted neutral.
/// Status/feedback colors are intentionally independent of the brand palette.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1A4BA3); // Logo Blue
  static const Color primaryBright = Color(0xFF2A62C4); // gradients, hover/active accents
  static const Color primaryLight = Color(0xFFE3ECFA); // tinted surfaces, selected states
  static const Color primaryDark = Color(0xFF12356F); // pressed states, gradient start
  static const Color navy = Color(0xFF0F1F3D); // deep navy — text, overlays, shadows
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Accent (logo orange). Use for highlights/decoration; for small text on a
  // light background use [accentDark], which meets contrast requirements.
  static const Color accent = Color(0xFFE8853A);
  static const Color accentDark = Color(0xFFB4530F);

  // Surfaces
  static const Color background = Color(0xFFF5F8FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFD5DFEE);

  // Text
  static const Color textPrimary = navy;
  static const Color textSecondary = Color(0xFF556583);
  static const Color textDisabled = Color(0xFF8A98B0);

  // Feedback
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);

  // Report status (Step 8 drives these off ReportStatus, defined once here)
  static const Color statusSubmitted = Color(0xFF64748B);
  static const Color statusInReview = Color(0xFFF59E0B);
  static const Color statusResolved = Color(0xFF16A34A);

  // ---- Dark theme ----
  // Light stays the primary/default visual design; these are only consulted
  // by `AppTheme.dark` and by widgets that set an explicit color and so must
  // branch on `Theme.of(context).brightness` themselves. Surfaces are
  // navy-tinted to match the logo's blue rather than neutral grey, sitting on
  // a true-black scaffold background.
  static const Color darkBackground = Color(0xFF000000); // true black
  static const Color darkSurface = Color(0xFF0D1627); // cards, app bar, nav bar
  static const Color darkSurfaceHigh = Color(0xFF16233B); // dialogs, sheets, menus
  static const Color darkBorder = Color(0xFF1F2E4A);
  static const Color darkTextPrimary = Color(0xFFE9EFFA);
  static const Color darkTextSecondary = Color(0xFF9AACC8);
  static const Color darkTextDisabled = Color(0xFF64779A);
  // Lighter logo blue for text/outlines/focus on dark surfaces — the regular
  // primary is too low-contrast as a foreground on navy.
  static const Color darkPrimary = Color(0xFF6B9CF0);
  static const Color darkPrimaryContainer = Color(0xFF1B3F7E); // selected states
}

/// Brightness-aware lookups for widgets that set an explicit color instead of
/// reading it from `Theme.of(context)`: each returns the light token in the
/// light theme and its dark counterpart in the dark theme.
extension AppColorsContext on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get backgroundColor => _isDark ? AppColors.darkBackground : AppColors.background;
  Color get surfaceColor => _isDark ? AppColors.darkSurface : AppColors.surface;
  Color get borderColor => _isDark ? AppColors.darkBorder : AppColors.border;
  Color get textPrimaryColor => _isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get textSecondaryColor => _isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

  /// Tinted/selected surface (`primaryLight` in light mode).
  Color get tintColor => _isDark ? AppColors.darkPrimaryContainer : AppColors.primaryLight;

  /// Brand blue for icons/text on the current surface (lighter in dark mode).
  Color get accentColor => _isDark ? AppColors.darkPrimary : AppColors.primary;
}
