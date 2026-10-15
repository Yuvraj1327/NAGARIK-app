import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/core/theme/app_spacing.dart';

/// The rounded, pill-shaped search field used by Home (as a tappable
/// shortcut, [readOnly] + [onTap]) and Search & Discover (a real input).
///
/// Deliberately has no microphone icon: NAGARIK has no voice-search feature,
/// and a control that does nothing would be worse than none.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.hintText = 'Search civic issues, locations…',
    this.readOnly = false,
    this.onTap,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController? controller;
  final String hintText;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;

  /// When set (and the field has text), a clear button is shown.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? AppColors.darkBorder : AppColors.border;

    OutlineInputBorder outline(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: color, width: width),
        );

    Widget? suffix;
    if (onClear != null && controller != null) {
      suffix = ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller!,
        builder: (context, value, _) => value.text.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Clear',
                onPressed: onClear,
              ),
      );
    }

    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: fill,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: AppSpacing.md),
        border: outline(border),
        enabledBorder: outline(border),
        focusedBorder: outline(AppColors.primary, 1.5),
      ),
    );
  }
}
