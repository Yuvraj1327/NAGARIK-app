import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Step 1 smoke test: proves the router + Riverpod + MaterialApp scaffold
/// renders without needing Supabase/env to be configured (that requires a
/// real .env, so this test builds a minimal router directly rather than
/// pulling in `NagarikApp`, which calls `Env.load()`/`initSupabase()` in
/// `main.dart`).
///
/// Real widget tests for actual screens arrive alongside each screen,
/// starting in Step 2.
void main() {
  testWidgets('root route renders the Step 1 placeholder screen', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('NAGARIK')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('NAGARIK'), findsOneWidget);
  });
}
