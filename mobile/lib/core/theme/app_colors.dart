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
}
