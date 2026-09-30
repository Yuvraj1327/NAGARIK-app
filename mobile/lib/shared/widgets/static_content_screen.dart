import 'package:flutter/material.dart';

import 'package:nagarik/core/theme/app_spacing.dart';
import 'package:nagarik/shared/widgets/primary_app_bar.dart';

/// One block of a [StaticContentScreen]: an optional heading followed by a
/// paragraph of body text.
class StaticContentSection {
  const StaticContentSection({this.heading, required this.body});

  final String? heading;
  final String body;
}

/// Shared layout for the app's long-form, mostly-static screens (Privacy
/// Policy, Terms & Conditions, About NAGARIK, Help & Support) — an app bar
/// plus a scrollable column of [StaticContentSection]s, so each of those
/// screens is just its own content, not its own layout code.
class StaticContentScreen extends StatelessWidget {
  const StaticContentScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<StaticContentSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: PrimaryAppBar(title: title),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: sections.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final section = sections[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (section.heading != null) ...[
                Text(section.heading!, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(section.body, style: theme.textTheme.bodyMedium),
            ],
          );
        },
      ),
    );
  }
}
