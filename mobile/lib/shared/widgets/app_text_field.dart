import 'package:flutter/material.dart';

/// The one text-field widget the whole app should use, so labels, borders,
/// and error styling stay consistent (driven by `AppTheme`'s
/// `inputDecorationTheme`).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.textInputAction,
    this.onChanged,
    this.enabled = true,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });


  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  /// Optional hard cap on input length (Step 9) — when set, Flutter both
  /// shows a counter and physically stops further input at the limit, so a
  /// field that mirrors a backend `max_length` constraint can't be typed
  /// past it in the first place.
  final int? maxLength;
  final IconData? prefixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      autovalidateMode: autovalidateMode,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      textInputAction: textInputAction,
      onChanged: onChanged,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
    );
  }
}
