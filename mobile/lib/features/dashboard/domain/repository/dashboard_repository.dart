import 'package:offline_alert/features/dashboard/domain/models/dashboard.dart';

/// Contract `DashboardService` is registered under, so tests can fake it.
abstract class DashboardRepository {
  Future<Dashboard> load();
}
