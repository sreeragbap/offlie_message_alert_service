import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Third-party objects the graph needs but does not construct.
///
/// Declared here rather than registered by hand in `configureDependencies()`
/// so the generator sees them and can flag a genuinely missing dependency.
@module
abstract class RegisterModule {
  /// Requires `Supabase.initialize` to have run, which `bootstrap()` ensures.
  @lazySingleton
  GoTrueClient get goTrueClient => Supabase.instance.client.auth;
}
