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
    this.focusNode,
    this.dense = false,
    this.showCounter = true,
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

  /// Optional (NAGARIK Theme upgrade) — lets a screen observe this field's
  /// focus state (e.g. `focusNode.addListener(...)`) without this widget
  /// needing to know why. Login/Signup pass one per field to drive their
  /// focus-blur hero effect; every other call site omits it and is
  /// unaffected (Flutter creates and owns an internal node as before).
  final FocusNode? focusNode;

  /// Compact vertical padding, for fields packed into filter bars/rows
  /// (Search) rather than standalone form fields.
  final bool dense;

  /// Set false to hide the "n/maxLength" counter [maxLength] otherwise
  /// shows — the length is still enforced, it just doesn't take a line.
  final bool showCounter;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
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
        isDense: dense,
        counterText: showCounter ? null : '',
        contentPadding: dense
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
            : null,
      ),
    );
  }
}
