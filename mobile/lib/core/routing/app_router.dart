import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nagarik/core/routing/go_router_refresh_stream.dart';
import 'package:nagarik/core/routing/scaffold_with_nav_bar.dart';
import 'package:nagarik/features/auth/presentation/screens/login_screen.dart';
import 'package:nagarik/features/auth/presentation/screens/signup_screen.dart';
import 'package:nagarik/features/discovery/presentation/screens/home_feed_screen.dart';
import 'package:nagarik/features/discovery/presentation/screens/search_screen.dart';
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
/// - `/login`, `/signup`, `/report/create`, `/report/:id` are pushed on the
///   root navigator (via `parentNavigatorKey`), so they render full-screen,
///   above the bottom nav.
///
/// Auth gate: every route in this app requires a signed-in user except
/// `/login` and `/signup` themselves — the app opens straight to the
/// login/signup screen, and Home, Search, Profile, "Report Issue", and a
/// report's detail page are all unreachable while signed out. (Earlier,
/// only `/report/create` was gated this way and Home/Search/Profile were
/// browsable while signed out; this replaces that with a hard gate in
/// front of the whole app shell.) Signed-in users are bounced away from
/// `/login`/`/signup` back to `/home` instead (there's nothing for an
/// already-authenticated user to do there). `refreshListenable` re-runs
/// this check whenever auth state changes — not just on navigation — so a
/// successful sign-in continues straight on to `/home`, and a sign-out
/// (from anywhere, e.g. the "Log out" button on Profile) is bounced
/// straight back to `/login`, with no extra navigation code needed either
/// way.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshStream = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      final location = state.matchedLocation;
      final isGoingToAuth = location == '/login' || location == '/signup';

      if (!isLoggedIn && !isGoingToAuth) return '/login';
      if (isLoggedIn && isGoingToAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/report/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateReportScreen(),
      ),
      GoRoute(
        path: '/report/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ReportDetailScreen(
          reportId: state.pathParameters['id']!,
        ),
      ),
      // Profile & Settings upgrade: all pushed full-screen on the root
      // navigator, same as the routes above — already covered by the
      // blanket auth gate since none of them is `/login`/`/signup`.
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/saved-reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SavedReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/help',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/legal/privacy',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/legal/terms',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: '/about',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
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
