import 'package:flutter/material.dart';

/// A Home-screen section title ("Nearby Issues", "Explore by Category",
/// "Recent Reports") with an optional trailing "See all" action.
///
/// Distinct from `shared/widgets/section_header.dart`'s `SectionHeader`
/// (an all-caps, low-emphasis group label used on Profile/Settings) —
/// Home's sections are the screen's primary content, so they get a
/// heavier, `titleMedium`-weight heading instead.
class DiscoverySectionHeader extends StatelessWidget {
  const DiscoverySectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('See all'),
          ),
      ],
    );
  }
}
