import 'package:flutter/material.dart';

import 'package:nagarik/shared/widgets/app_card.dart';
import 'package:nagarik/shared/widgets/section_header.dart';

/// A labeled group of [SettingsListTile]s in one card with dividers between
/// them (e.g. Profile's "MY ACTIVITY"/"SETTINGS"/"LEGAL"/"ACCOUNT" groups,
/// or Settings' own grouped rows) — the one place this layout is defined,
/// so every group looks identical.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, this.title, required this.tiles});

  /// Omit (or pass null) to render just the card with no header above it —
  /// useful when a [SectionHeader] for this group is already provided
  /// separately, or when a screen wants several cards under one shared
  /// header (see `SettingsScreen`'s "Account information" section).
  final String? title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) SectionHeader(title: title!),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i != tiles.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
