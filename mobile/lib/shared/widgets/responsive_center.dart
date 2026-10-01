import 'package:flutter/material.dart';

/// Centers [child] and caps its width at [maxWidth] on a wide viewport (UI
/// Polish upgrade's "make the UI responsive for mobile, web and macOS")
/// — so lists, forms, and detail pages don't stretch uncomfortably
/// edge-to-edge in a browser tab or a resized desktop window.
///
/// On an ordinary phone-width viewport [maxWidth] is never reached, so this
/// renders completely unchanged there — it's a no-op wrapper below that
/// width, not a second phone/desktop layout to maintain.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 640});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
