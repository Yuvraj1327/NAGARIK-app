import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A shared, subtle fade + slight-upward-slide transition (UI Polish
/// upgrade) for every screen this app pushes on top of the bottom-nav
/// shell on the root navigator — login/signup, report create/detail, edit
/// profile, saved reports, settings, help, the legal pages, and about (see
/// `app_router.dart`, every `GoRoute` with `parentNavigatorKey:
/// _rootNavigatorKey`).
///
/// Deliberately NOT applied to the four `StatefulShellRoute` tab routes
/// themselves (Home/Search/My Reports/Profile) — those must keep their
/// existing instant `IndexedStack` tab switch (preserving each tab's own
/// navigation stack and scroll position), not a push/pop-style transition.
CustomTransitionPage<T> fadeSlidePage<T>({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
