import 'package:flutter/material.dart';

import 'package:nagarik/shared/widgets/logo.dart';
import 'package:nagarik/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    return StaticContentScreen(
      title: l10n.legalAboutNagarik,
      header: const Center(child: Padding(padding: EdgeInsets.only(bottom: 8), child: Logo(size: 88))),
      sections: [
        StaticContentSection(
          heading: l10n.legalAboutHeading,
          body: l10n.legalAboutBody,
        ),
        StaticContentSection(
          heading: l10n.legalAboutHowHeading,
          body: l10n.legalAboutHowBody,
        ),
        StaticContentSection(
          heading: l10n.legalVersionHeading,
          body: l10n.legalVersionBody,
        ),
      ],
    );
  }
}
