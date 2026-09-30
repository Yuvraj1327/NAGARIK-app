import 'package:flutter/material.dart';

/// The one official NAGARIK logo (`assets/images/nagarik_logo.png`),
/// wrapped as a single reusable widget so every screen that shows the
/// brand mark — the startup splash, Login/Signup, the Home app bar, the
/// navigation drawer, and About NAGARIK — renders the exact same asset the
/// exact same way, instead of each screen reaching for its own
/// `Image.asset` call.
///
/// The source file is square, and this widget always lays it out in a
/// square box (`width == height == size`) with `BoxFit.contain`, so the
/// logo's aspect ratio can never be stretched or cropped no matter what
/// [size] a caller passes.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 96, this.borderRadius});

  /// Both the width and height of the box the logo is drawn in.
  final double size;

  /// Optional rounded corners — left `null` (square corners, the
  /// artwork's own edges) everywhere except where a screen wants a
  /// softened, icon-like mark (e.g. a small app-bar mark).
  final BorderRadius? borderRadius;

  /// Exposed so any future platform app-icon tooling can point at the same
  /// single source file this widget uses.
  static const String assetPath = 'assets/images/nagarik_logo.png';

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'NAGARIK logo',
      // Defensive fallback only — the asset ships in the app bundle and is
      // declared in pubspec.yaml, so this should never actually trigger.
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.shield_outlined,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
