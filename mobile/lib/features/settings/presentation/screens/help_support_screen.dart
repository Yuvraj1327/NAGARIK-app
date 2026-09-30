import 'package:flutter/material.dart';

import 'package:nagarik/shared/widgets/static_content_screen.dart';

/// Profile/Settings -> Help & Support. Placeholder FAQ + contact details —
/// this is not a live chat/ticketing integration (explicitly out of scope
/// for this app), just static guidance and a contact address.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StaticContentScreen(
      title: 'Help & Support',
      sections: [
        StaticContentSection(
          heading: 'How do I submit a report?',
          body: 'Tap "Report Issue" from any tab, choose a category, add a '
              'description, confirm your location and city/PIN code, and '
              'optionally attach photos.',
        ),
        StaticContentSection(
          heading: 'How do I check a report\'s status?',
          body: 'Open Profile -> My Reports to see every report you\'ve '
              'submitted along with its current status: Submitted, In Review, '
              'or Resolved.',
        ),
        StaticContentSection(
          heading: 'How do I change my name?',
          body: 'Open Profile -> Edit Profile.',
        ),
        StaticContentSection(
          heading: 'Still need help?',
          body: 'Reach us at support@nagarik.example.',
        ),
      ],
    );
  }
}
