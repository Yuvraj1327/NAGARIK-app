import 'package:flutter/material.dart';

import 'package:nagarik/l10n/app_localizations.dart';
import 'package:nagarik/shared/widgets/static_content_screen.dart';

/// Profile/Settings -> Help & Support. Placeholder FAQ + contact details —
/// this is not a live chat/ticketing integration (explicitly out of scope
/// for this app), just static guidance and a contact address.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StaticContentScreen(
      title: l10n.setHelpSupport,
      sections: [
        StaticContentSection(
          heading: l10n.setHelpSubmitQ,
          body: l10n.setHelpSubmitA,
        ),
        StaticContentSection(
          heading: l10n.setHelpStatusQ,
          body: l10n.setHelpStatusA,
        ),
        StaticContentSection(
          heading: l10n.setHelpNameQ,
          body: l10n.setHelpNameA,
        ),
        StaticContentSection(
          heading: l10n.setHelpMoreQ,
          body: l10n.setHelpMoreA,
        ),
      ],
    );
  }
}
