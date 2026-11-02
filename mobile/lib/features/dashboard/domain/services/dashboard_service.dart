import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/network/api_client.dart';
import 'package:offline_alert/features/dashboard/domain/models/dashboard.dart';
import 'package:offline_alert/features/dashboard/domain/repository/dashboard_repository.dart';

@LazySingleton(as: DashboardRepository)
class DashboardService implements DashboardRepository {
  DashboardService(this._api);

  final ApiClient _api;

  @override
  Future<Dashboard> load() async =>
      Dashboard.fromJson(await _api.get('/dashboard') as Map<String, dynamic>);
}
