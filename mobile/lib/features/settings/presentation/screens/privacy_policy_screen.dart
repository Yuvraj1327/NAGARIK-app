import 'package:flutter/material.dart';

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
    return const StaticContentScreen(
      title: 'Privacy Policy',
      sections: [
        StaticContentSection(
          body: 'This is placeholder text describing how NAGARIK handles your '
              'information. Replace it with your reviewed privacy policy before '
              'a real release.',
        ),
        StaticContentSection(
          heading: 'What we collect',
          body: 'Your name and email address (when you create an account), and '
              'the reports you submit — a category, description, city and PIN '
              'code, optional photos, and location coordinates when you choose '
              'to attach one.',
        ),
        StaticContentSection(
          heading: 'How we use it',
          body: 'To show your submitted reports back to you, to let other '
              'citizens browse and search civic issues in their area, and to '
              'track a report\'s status as it moves from Submitted to In '
              'Review to Resolved.',
        ),
        StaticContentSection(
          heading: 'Where it is stored',
          body: 'Account and report data is stored with Supabase; photos are '
              'stored in a private file bucket and are never publicly '
              'browsable by their raw address.',
        ),
        StaticContentSection(
          heading: 'Sharing',
          body: 'We do not sell your personal information to third parties.',
        ),
        StaticContentSection(
          heading: 'Contact',
          body: 'Questions about this policy can be sent to '
              'privacy@nagarik.example.',
        ),
      ],
    );
  }
}
