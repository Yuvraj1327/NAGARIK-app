import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:nagarik/core/theme/app_colors.dart';
import 'package:nagarik/shared/widgets/animations/pressable_scale.dart';

/// Shared scaffold for the four bottom-nav tabs (Home, Search, My Reports,
/// Profile — Report Sharing, Saved Reports & Final Feature Polish upgrade
/// added My Reports as the fourth primary destination; see
/// `app_router.dart`). Every other feature (Saved Reports, Report Issue,
/// Map/Nearby, Settings, legal pages, About, Logout) lives in the
/// `AppDrawer` each of these four tabs' own `Scaffold` declares, keeping the
/// bottom bar itself to just the handful of features used often enough to
/// deserve one-tap access.
///
/// Home/Drawer/Search/My Reports redesign: the bar is now a rounded, softly
/// shadowed surface with a pill-highlighted active item, and "Report Issue"
/// — the app's primary action, always reachable from every tab — is a
/// raised round "+" button in the middle of the bar instead of an extended
/// floating button. It is not a fifth destination: it pushes the same
/// `/report/create` route the FAB always did.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(color: Color(0x1A12213A), blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: current == 0,
                  onTap: () => _onTap(0),
                ),
                _NavItem(
                  icon: Icons.search_rounded,
                  selectedIcon: Icons.search_rounded,
                  label: 'Search',
                  selected: current == 1,
                  onTap: () => _onTap(1),
                ),
                const Expanded(child: _ReportButton()),
                _NavItem(
                  icon: Icons.assignment_outlined,
                  selectedIcon: Icons.assignment_rounded,
                  label: 'My Reports',
                  selected: current == 2,
                  onTap: () => _onTap(2),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Profile',
                  selected: current == 3,
                  onTap: () => _onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryLight : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? selectedIcon : icon, size: 24, color: color),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The raised center "+" — opens the guided Report Issue flow.
class _ReportButton extends StatelessWidget {
  const _ReportButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -10),
        child: PressableScale(
          child: Semantics(
            button: true,
            label: 'Report an issue',
            child: Material(
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: AppColors.primary.withOpacity(0.5),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/report/create'),
                child: Ink(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryBright, AppColors.primary],
                    ),
                  ),
                  child: const Icon(Icons.add_rounded, size: 32, color: AppColors.onPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
