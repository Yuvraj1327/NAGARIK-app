import 'package:flutter/material.dart';

import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/shared/widgets/static_content_screen.dart';

/// Profile/Settings -> Terms & Conditions.
///
/// Placeholder copy — replace with reviewed legal terms before a real
/// release, same caveat as `PrivacyPolicyScreen`.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StaticContentScreen(
      title: l10n.legalTermsConditions,
      sections: [
        StaticContentSection(
          body: l10n.legalTermsIntro,
        ),
        StaticContentSection(
          heading: l10n.legalTermsUsingHeading,
          body: l10n.legalTermsUsingBody,
        ),
        StaticContentSection(
          heading: l10n.legalTermsAccountHeading,
          body: l10n.legalTermsAccountBody,
        ),
        StaticContentSection(
          heading: l10n.legalTermsNoGuaranteeHeading,
          body: l10n.legalTermsNoGuaranteeBody,
        ),
        StaticContentSection(
          heading: l10n.legalTermsChangesHeading,
          body: l10n.legalTermsChangesBody,
        ),
      ],
    );
  }
}
