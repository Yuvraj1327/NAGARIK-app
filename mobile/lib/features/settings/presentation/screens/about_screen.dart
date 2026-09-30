import 'package:flutter/material.dart';

import 'package:nagarik/shared/widgets/logo.dart';
import 'package:nagarik/shared/widgets/static_content_screen.dart';

/// Profile/Settings -> About NAGARIK.
///
/// The version string below is hardcoded rather than pulled from
/// `pubspec.yaml` at runtime — a `package_info_plus` dependency for one
/// static line felt like more package than the feature warrants. Keep this
/// in sync with `pubspec.yaml`'s `version:` field by hand, or wire up
/// `package_info_plus` in a later step if that becomes annoying.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaticContentScreen(
      title: 'About NAGARIK',
      header: Center(child: Padding(padding: EdgeInsets.only(bottom: 8), child: Logo(size: 88))),
      sections: [
        StaticContentSection(
          heading: 'NAGARIK — A Civic Good Initiative',
          body: 'NAGARIK gives citizens a simple way to report civic issues — '
              'potholes, broken streetlights, sanitation problems, water and '
              'electricity faults, safety hazards, and more — and to track '
              'each report from Submitted through In Review to Resolved.',
        ),
        StaticContentSection(
          heading: 'How it works',
          body: 'Report an issue with a description, category, location, and '
              'photos. Browse and search reports from your city or nearby. '
              'Follow your own reports\' status from your Profile.',
        ),
        StaticContentSection(
          heading: 'Version',
          body: 'NAGARIK 0.1.0',
        ),
      ],
    );
  }
}
