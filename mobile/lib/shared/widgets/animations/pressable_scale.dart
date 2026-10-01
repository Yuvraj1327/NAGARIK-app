import 'package:flutter/material.dart';

/// Wraps [child] with a small, fast scale-down while pressed (UI Polish
/// upgrade) — the app's shared "press feedback" primitive for cards and
/// buttons (the redesign brief's "Buttons and interactive elements should
/// have small scale/press feedback").
///
/// Uses a [Listener] rather than a [GestureDetector] deliberately: a
/// [Listener] only observes raw pointer down/up/cancel events and never
/// joins the gesture arena, so it can wrap a child that already handles its
/// own taps (an `InkWell`, `ElevatedButton`, `OutlinedButton`, ...) without
/// competing with it for the tap — the child's own `onTap`/`onPressed`
/// still fires exactly as before, this only drives the scale animation
/// alongside it.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 100),
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final Duration duration;

  /// When false, never scales down (e.g. a card/button with no `onTap` —
  /// nothing to give feedback for).
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
