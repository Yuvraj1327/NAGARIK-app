import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges any [Stream] (here, Supabase's `onAuthStateChange`) into a
/// [Listenable], which is what go_router's `refreshListenable` needs to
/// re-evaluate `redirect` whenever auth state changes — without this, the
/// router would only re-check `redirect` on an actual navigation, not when
/// the user signs in/out while already sitting on a screen.
///
/// This is the standard go_router recipe for stream-driven redirects.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
