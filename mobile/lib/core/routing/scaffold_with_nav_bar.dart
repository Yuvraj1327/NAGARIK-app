import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared scaffold for the four bottom-nav tabs (Home, Search, My Reports,
/// Profile — Report Sharing, Saved Reports & Final Feature Polish upgrade
/// added My Reports as the fourth primary destination, moved here from a
/// screen pushed off Profile; see `app_router.dart`). Every other feature
/// (Saved Reports, Report Issue, Map/Nearby, Settings, legal pages, About,
/// Logout) lives in the `AppDrawer` each of these four tabs' own `Scaffold`
/// declares, keeping the bottom bar itself to just the handful of features
/// used often enough to deserve one-tap access, per the hybrid navigation
/// brief's "do not overcrowd the bottom navigation".
///
/// The "Report Issue" FAB is always visible regardless of tab, since
/// reporting an issue is the app's primary action (Home -> Report Issue ->
/// ... in the original approved UX flow) — kept as a FAB rather than a
/// fifth bottom-nav destination so the bar itself stays at four.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/report/create'),
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Report Issue'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'My Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
