import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/app.dart';
import 'package:nagarik/core/config/env.dart';
import 'package:nagarik/core/network/supabase_client_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  await initSupabase();

  runApp(const ProviderScope(child: NagarikApp()));
}
