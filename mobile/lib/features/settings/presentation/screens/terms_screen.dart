import 'package:flutter/material.dart';

import 'package:nagarik/shared/widgets/static_content_screen.dart';

/// Profile/Settings -> Terms & Conditions.
///
/// Placeholder copy — replace with reviewed legal terms before a real
/// release, same caveat as `PrivacyPolicyScreen`.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaticContentScreen(
      title: 'Terms & Conditions',
      sections: [
        StaticContentSection(
          body: 'This is placeholder text. Replace it with your reviewed terms '
              'of use before a real release.',
        ),
        StaticContentSection(
          heading: 'Using NAGARIK',
          body: 'NAGARIK is a civic issue reporting app. Reports you submit '
              'should be accurate and made in good faith — NAGARIK is not the '
              'right place for spam, harassment, or reports about private '
              'individuals rather than civic infrastructure or services.',
        ),
        StaticContentSection(
          heading: 'Your account',
          body: 'You are responsible for the reports submitted under your '
              'account. We may suspend or remove an account that misuses the '
              'app.',
        ),
        StaticContentSection(
          heading: 'No guaranteed resolution',
          body: 'Submitting a report shares it with other citizens and (where '
              'applicable) the relevant authority, but NAGARIK does not '
              'guarantee any particular resolution time or outcome for a '
              'reported issue.',
        ),
        StaticContentSection(
          heading: 'Changes',
          body: 'These terms may be updated from time to time; continuing to '
              'use the app after a change means you accept the updated terms.',
        ),
      ],
    );
  }
}
