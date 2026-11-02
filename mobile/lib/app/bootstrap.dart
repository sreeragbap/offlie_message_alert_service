import 'package:flutter/material.dart';
import 'package:offline_alert/app/app.dart';
import 'package:offline_alert/app/app_config.dart';
import 'package:offline_alert/core/di/injection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Startup path. Ordering matters:
///   1. Config check, so a build without env.json says so instead of crashing.
///   2. Supabase, because DI hands its auth client to the graph.
///   3. DI, so services exist (local notifications are initialised here too).
///   4. `runApp`.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isConfigured) {
    runApp(const ConfigMissingApp());
    return;
  }
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabasePublishableKey);
  await configureDependencies();
  runApp(const App());
}
