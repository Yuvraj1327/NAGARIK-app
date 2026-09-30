import 'package:flutter/material.dart';

/// Centralized color palette. Nothing outside this class should hardcode a
/// `Color(0x...)` literal for anything that appears more than once.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);

  // Feedback
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);

  // Report status (Step 8 drives these off ReportStatus, defined once here)
  static const Color statusSubmitted = Color(0xFF64748B);
  static const Color statusInReview = Color(0xFFF59E0B);
  static const Color statusResolved = Color(0xFF16A34A);

  // ---- Dark theme (Profile & Settings upgrade) ----
  // Light stays the primary/default visual design (per the project brief);
  // these are only consulted by `AppTheme.dark` and by the handful of
  // widgets — currently just `AppCard` — that set an explicit color rather
  // than reading it from `Theme.of(context)`, and therefore need to branch
  // on `Theme.of(context).brightness` themselves to support dark mode at
  // all. Brand/feedback/status colors above are reused as-is in dark mode;
  // they're mid-tone/saturated enough to stay legible on a dark surface.
  static const Color darkBackground = Color(0xFF0B1220);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkBorder = Color(0xFF1F2937);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextDisabled = Color(0xFF64748B);
}
