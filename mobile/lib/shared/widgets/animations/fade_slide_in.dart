import 'package:flutter/material.dart';

/// A one-shot fade + slight upward-slide entrance animation (UI Polish
/// upgrade), used to give cards and sections a soft "settle into place"
/// feel when a screen first renders or a list item first appears.
///
/// Deliberately dependency-free — just [AnimationController]/
/// [CurvedAnimation] — matching this project's standing "avoid unnecessary
/// packages" precedent (see `app_typography.dart`'s own doc comment) rather
/// than reaching for an animation package.
///
/// Pass [delay] to stagger a list of these (e.g.
/// `delay: Duration(milliseconds: 40 * index)`) so items settle in one
/// after another instead of all at once — used by the report list screens'
/// `itemBuilder`s.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
    this.offset = const Offset(0, 0.06),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
