import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/di/injection.config.dart';

final GetIt getIt = GetIt.instance;

/// Wires up the object graph. Called once from `bootstrap()` before `runApp`,
/// after `Supabase.initialize` (see `RegisterModule`).
@InjectableInit()
Future<void> configureDependencies() => getIt.init();

/// Clears every registration. Test-only; production never tears down the graph.
Future<void> resetDependencies() => getIt.reset();
