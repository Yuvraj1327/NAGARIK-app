import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nagarik/shared/widgets/app_button.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';

void main() {
  testWidgets('AppButton shows its label and responds to taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(label: 'Submit', onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.text('Submit'), findsOneWidget);
    await tester.tap(find.text('Submit'));
    expect(tapped, isTrue);
  });

  testWidgets('EmptyView shows its title and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyView(
            icon: Icons.inbox_outlined,
            title: 'Nothing here',
            message: 'Come back later.',
          ),
        ),
      ),
    );

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Come back later.'), findsOneWidget);
  });
}
