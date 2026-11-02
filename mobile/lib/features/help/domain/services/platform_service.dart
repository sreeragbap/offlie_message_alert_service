import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/network/api_client.dart';
import 'package:offline_alert/features/help/domain/models/platform_info.dart';
import 'package:offline_alert/features/help/domain/repository/platform_repository.dart';

@LazySingleton(as: PlatformRepository)
class PlatformService implements PlatformRepository {
  PlatformService(this._api);

  final ApiClient _api;

  @override
  Future<List<PlatformInfo>> list() async {
    final json = await _api.get('/platforms') as List;
    return json.map((e) => PlatformInfo.fromJson(e as Map<String, dynamic>)).toList();
  }
}
