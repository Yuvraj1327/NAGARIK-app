import 'package:flutter/material.dart';

import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/shared/widgets/static_content_screen.dart';

/// Profile/Settings -> Privacy Policy.
///
/// Placeholder copy describing what this app actually does with data,
/// written to be accurate to this codebase (Supabase Auth for accounts,
/// the `reports` table + private Storage bucket for report content) — but
/// it is NOT a substitute for review by whoever is legally responsible for
/// this app before a real release. Replace this text with reviewed legal
/// copy before shipping to real users.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StaticContentScreen(
      title: l10n.legalPrivacyPolicy,
      sections: [
        StaticContentSection(
          body: l10n.legalPrivacyIntro,
        ),
        StaticContentSection(
          heading: l10n.legalPrivacyCollectHeading,
          body: l10n.legalPrivacyCollectBody,
        ),
        StaticContentSection(
          heading: l10n.legalPrivacyUseHeading,
          body: l10n.legalPrivacyUseBody,
        ),
        StaticContentSection(
          heading: l10n.legalPrivacyStoredHeading,
          body: l10n.legalPrivacyStoredBody,
        ),
        StaticContentSection(
          heading: l10n.legalPrivacySharingHeading,
          body: l10n.legalPrivacySharingBody,
        ),
        StaticContentSection(
          heading: l10n.legalContactHeading,
          body: l10n.legalPrivacyContactBody,
        ),
      ],
    );
  }
}
