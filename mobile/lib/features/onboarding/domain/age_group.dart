/// Onboarding redesign: the optional age bracket asked on Step 4 — never a
/// hard gate (the brief's "do not unnecessarily block the app" and "keep
/// this step optional"), just a stored, self-reported bracket with no
/// backend field or downstream content restriction yet attached to it.
enum AgeGroup {
  eighteenOrOlder,
  underEighteen;

  String get label => switch (this) {
        AgeGroup.eighteenOrOlder => '18 or older',
        AgeGroup.underEighteen => 'Under 18',
      };
}
