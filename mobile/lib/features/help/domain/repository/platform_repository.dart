import 'package:offline_alert/features/help/domain/models/platform_info.dart';

/// Contract `PlatformService` is registered under, so tests can fake it.
abstract class PlatformRepository {
  Future<List<PlatformInfo>> list();
}
