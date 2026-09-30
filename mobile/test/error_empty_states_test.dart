import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nagarik/core/network/api_exception.dart';
import 'package:nagarik/shared/widgets/empty_view.dart';
import 'package:nagarik/shared/widgets/error_view.dart';

/// Final Feature Polish upgrade: `ErrorView.forError` is the one place that
/// decides "network error" vs "API error" presentation, and the `EmptyView`
/// named constructors are the one place each reusable empty-state's copy
/// lives — both worth covering directly so every screen that delegates to
/// them (Home, Search, My Reports, Saved Reports, Report Detail, ...) stays
/// correct without re-testing the same logic per screen.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ErrorView.forError', () {
    testWidgets('shows a connection-specific message and icon for a network failure', (
      tester,
    ) async {
      const error = ApiException(message: 'Connection timed out');

      await tester.pumpWidget(wrap(ErrorView.forError(error)));

      expect(error.isNetworkError, isTrue);
      expect(find.textContaining("Can't reach NAGARIK"), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
    });

    testWidgets('shows the backend-provided message for a server error', (tester) async {
      const error = ApiException(message: 'Report not found.', statusCode: 404);

      await tester.pumpWidget(wrap(ErrorView.forError(error)));

      expect(error.isNetworkError, isFalse);
      expect(find.text('Report not found.'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('falls back to the given message for a non-ApiException error', (tester) async {
      await tester.pumpWidget(
        wrap(ErrorView.forError(Exception('boom'), fallbackMessage: 'Something specific broke.')),
      );

      expect(find.text('Something specific broke.'), findsOneWidget);
    });

    testWidgets('renders a Retry button only when onRetry is given', (tester) async {
      const error = ApiException(message: 'Report not found.', statusCode: 404);

      await tester.pumpWidget(wrap(ErrorView.forError(error, onRetry: () {})));
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

      await tester.pumpWidget(wrap(ErrorView.forError(error)));
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsNothing);
    });
  });

  group('EmptyView presets', () {
    testWidgets('noReports shows its title and an optional action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(EmptyView.noReports(actionLabel: 'Report an Issue', onAction: () => tapped = true)),
      );

      expect(find.text('No reports yet'), findsOneWidget);
      await tester.tap(find.text('Report an Issue'));
      expect(tapped, isTrue);
    });

    testWidgets('noSavedReports shows saved-specific copy', (tester) async {
      await tester.pumpWidget(wrap(const EmptyView.noSavedReports()));
      expect(find.text('No saved reports yet'), findsOneWidget);
    });

    testWidgets('noNearbyReports shows nearby-specific copy', (tester) async {
      await tester.pumpWidget(wrap(const EmptyView.noNearbyReports()));
      expect(find.text('No civic issues nearby'), findsOneWidget);
    });

    testWidgets('searchNoResults shows search-specific copy', (tester) async {
      await tester.pumpWidget(wrap(const EmptyView.searchNoResults()));
      expect(find.text('No matching reports'), findsOneWidget);
    });
  });
}
