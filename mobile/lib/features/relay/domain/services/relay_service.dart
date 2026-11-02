import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/network/api_client.dart';
import 'package:offline_alert/core/sms/sms_relay_channel.dart';
import 'package:offline_alert/features/relay/domain/models/relay_job.dart';
import 'package:offline_alert/features/relay/domain/repository/relay_repository.dart';

@LazySingleton(as: RelayRepository)
class RelayService implements RelayRepository {
  RelayService(this._api);

  final ApiClient _api;

  @override
  Future<List<RelayJob>> claim() async {
    final json = await _api.post('/relay/claim');
    return (json as List).map((e) => RelayJob.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> report(String alertId, RelaySendOutcome outcome, String? error) =>
      _api.post('/relay/alerts/$alertId/result', {'outcome': outcome.wire, 'error': ?error});
}
