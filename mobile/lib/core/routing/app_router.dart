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
import 'package:nagarik/features/profile/presentation/screens/profile_screen.dart';
import 'package:nagarik/features/reports/presentation/screens/create_report_screen.dart';
import 'package:nagarik/features/reports/presentation/screens/report_detail_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide route configuration.
///
/// - `/home`, `/search`, `/profile` sit inside a `StatefulShellRoute` so
///   they share the bottom navigation bar and each keep their own
///   navigation stack and scroll position when switching tabs.
/// - `/login`, `/signup`, `/report/create`, `/report/:id` are pushed on the
///   root navigator (via `parentNavigatorKey`), so they render full-screen,
///   above the bottom nav.
///
/// Auth-gated redirect (Step 3): reporting an issue requires a signed-in
/// user (Step 5 links every report to its author), so `/report/create`
/// bounces to `/login` when signed out. Signed-in users are bounced away
/// from `/login`/`/signup` back to `/home`. `refreshListenable` re-runs
/// this check whenever auth state changes — not just on navigation — so a
/// successful sign-in on the login screen automatically continues on to
/// `/home` with no extra navigation code needed there.
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
      final isGoingToCreateReport = location == '/report/create';

      if (isGoingToCreateReport && !isLoggedIn) return '/login';
      if (isGoingToAuth && isLoggedIn) return '/home';
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
                builder: (context, state) => const SearchScreen(),
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
