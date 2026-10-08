import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nagarik/core/routing/go_router_refresh_stream.dart';
import 'package:nagarik/core/routing/page_transitions.dart';
import 'package:nagarik/core/routing/scaffold_with_nav_bar.dart';
import 'package:nagarik/features/auth/presentation/screens/auth_welcome_screen.dart';
import 'package:nagarik/features/auth/presentation/screens/login_screen.dart';
import 'package:nagarik/features/auth/presentation/screens/signup_screen.dart';
import 'package:nagarik/features/discovery/presentation/screens/home_feed_screen.dart';
import 'package:nagarik/features/discovery/presentation/screens/search_screen.dart';
import 'package:nagarik/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:nagarik/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:nagarik/features/profile/presentation/screens/profile_screen.dart';
import 'package:nagarik/features/reports/presentation/screens/create_report_screen.dart';
import 'package:nagarik/features/reports/presentation/screens/my_reports_screen.dart';
import 'package:nagarik/features/reports/presentation/screens/report_detail_screen.dart';
import 'package:nagarik/features/reports/presentation/screens/saved_reports_screen.dart';
import 'package:nagarik/features/settings/presentation/screens/about_screen.dart';
import 'package:nagarik/features/settings/presentation/screens/help_support_screen.dart';
import 'package:nagarik/features/settings/presentation/screens/privacy_policy_screen.dart';
import 'package:nagarik/features/settings/presentation/screens/settings_screen.dart';
import 'package:nagarik/features/settings/presentation/screens/terms_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide route configuration.
///
/// - `/home`, `/search`, `/my-reports`, `/profile` sit inside a
///   `StatefulShellRoute` so they share the bottom navigation bar and each
///   keep their own navigation stack and scroll position when switching
///   tabs — the hybrid navigation structure's four primary, bottom-bar
///   destinations (Report Sharing, Saved Reports & Final Feature Polish
///   upgrade moved My Reports here from a screen pushed off Profile; see
///   that upgrade's notes in `docs/ARCHITECTURE.md`). Every remaining
///   screen — Saved Reports, Settings, Help & Support, the legal pages,
///   About, and Logout — is reached from the same `AppDrawer`
///   (`core/routing/app_drawer.dart`) on all four of those screens, so
///   nothing needs a second, drawer-only copy of a route.
/// - `/onboarding`, `/welcome`, `/login`, `/signup`, `/report/create`,
///   `/report/:id` are pushed on the root navigator (via
///   `parentNavigatorKey`), so they render full-screen, above the bottom
///   nav.
///
/// Auth gate (NAGARIK Theme upgrade; extended by the Onboarding redesign):
/// every route in this app requires a signed-in user except `/onboarding`,
/// `/welcome`, `/login`, and `/signup` — Home, Search, Profile, "Report
/// Issue", and a report's detail page all stay unreachable while signed
/// out. Signed-in users are bounced away from any of those four screens
/// back to `/home` instead (there's nothing for an already-authenticated
/// user to do on any of them — including onboarding, which a signed-in
/// user should never see at all). `refreshListenable` re-runs this check
/// whenever auth state changes — not just on navigation — so a successful
/// sign-in (Email/Password or "Continue with Google") continues straight
/// on to `/home`, and a sign-out or expired session (from anywhere, e.g.
/// the "Log out" button on Profile) is bounced straight back to
/// `/welcome` (not `/onboarding` — a returning signed-out user who has
/// already seen onboarding shouldn't see it again; see [initialLocation]
/// below for where that decision is actually made), with no extra
/// navigation code needed either way.
///
/// [initialLocation] is computed once at app startup
/// (`app.dart`'s `_bootstrap`) rather than hardcoded here, specifically so
/// a first-time, signed-out launch can start on `/onboarding` while every
/// other case (already onboarded, or already signed in) keeps starting on
/// `/welcome`/`/home` exactly as before the Onboarding redesign — the
/// `redirect` above intentionally does NOT depend on onboarding-completion
/// state at all, since `OnboardingScreen` itself navigates away
/// (`context.go('/welcome')`) once finished or skipped, and re-deciding
/// the *initial* screen on every redirect call would be both unnecessary
/// and, since that state loads asynchronously, harder to get right than
/// computing it once before the router is even built.
final appRouterProvider = Provider.family<GoRouter, String>((ref, initialLocation) {
  final refreshStream = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      final location = state.matchedLocation;
      final isGoingToAuth = location == '/onboarding' ||
          location == '/welcome' ||
          location == '/login' ||
          location == '/signup';

      if (!isLoggedIn && !isGoingToAuth) return '/welcome';
      if (isLoggedIn && isGoingToAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const OnboardingScreen()),
      ),
      // UI Polish upgrade: every route on the root navigator below uses
      // `pageBuilder` + `fadeSlidePage` (core/routing/page_transitions.dart)
      // instead of a plain `builder`, so pushing/popping any of these full-
      // screen routes fades + slides in rather than Flutter's default
      // platform transition — purely a transition change, every screen's
      // own widget and the auth-gate `redirect` above are untouched.
      GoRoute(
        path: '/welcome',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const AuthWelcomeScreen()),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const SignupScreen()),
      ),
      GoRoute(
        path: '/report/create',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const CreateReportScreen()),
      ),
      GoRoute(
        path: '/report/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => fadeSlidePage(
          key: state.pageKey,
          child: ReportDetailScreen(reportId: state.pathParameters['id']!),
        ),
      ),
      // Profile & Settings upgrade: all pushed full-screen on the root
      // navigator, same as the routes above — already covered by the
      // blanket auth gate since none of them is `/login`/`/signup`.
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const EditProfileScreen()),
      ),
      GoRoute(
        path: '/profile/saved-reports',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const SavedReportsScreen()),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/help',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const HelpSupportScreen()),
      ),
      GoRoute(
        path: '/legal/privacy',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const PrivacyPolicyScreen()),
      ),
      GoRoute(
        path: '/legal/terms',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const TermsScreen()),
      ),
      GoRoute(
        path: '/about',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const AboutScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                // Location Discovery & Home upgrade: Home's "See all"/
                // category-tile shortcuts land here with query params
                // instead of duplicating Search's own filter logic
                // (`?category=road`, `?nearby=true`, `?all=true`) — parsed
                // once here into `SearchScreen`'s constructor, which runs
                // the matching search on first frame. The app drawer's
                // "Map / Nearby" entry (Report Sharing, Saved Reports &
                // Final Feature Polish upgrade) adds `?view=map` on top of
                // `?nearby=true`, landing here already switched to nearby
                // results in the Map view — still this one screen, no
                // second "nearby/map" screen built for it.
                builder: (context, state) {
                  final params = state.uri.queryParameters;
                  return SearchScreen(
                    initialCategoryName: params['category'],
                    initialNearby: params['nearby'] == 'true',
                    initialShowAll: params['all'] == 'true',
                    initialView: params['view'],
                  );
                },
              ),
            ],
          ),
          // Report Sharing, Saved Reports & Final Feature Polish upgrade:
          // My Reports moved here from a screen pushed off Profile
          // (`/profile/my-reports`) to its own top-level tab — it's a
          // primary, frequently-used feature (the hybrid nav brief's
          // "4-5 most important features" in the bottom bar), not a
          // secondary Profile setting. Same `MyReportsScreen`, same data —
          // just a different, single route reached from both the bottom
          // bar and the drawer, rather than a second copy of the screen.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-reports',
                builder: (context, state) => const MyReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
