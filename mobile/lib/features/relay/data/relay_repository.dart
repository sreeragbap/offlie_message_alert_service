import '../../../core/network/api_client.dart';
import '../../../core/sms/sms_relay_channel.dart';

/// An SMS the backend wants this relay phone to send now.
class RelayJob {
  const RelayJob({required this.alertId, required this.toE164, required this.text});

  final String alertId;
  final String toE164;
  final String text;

  factory RelayJob.fromJson(Map<String, dynamic> json) =>
      RelayJob(alertId: json['alertId'] as String, toE164: json['toE164'] as String, text: json['text'] as String);
}

class RelayRepository {
  RelayRepository(this._api);

  final ApiClient _api;

  /// Claims due SMS jobs. Each one is leased to this phone for two minutes.
  Future<List<RelayJob>> claim() async {
    final json = await _api.post('/relay/claim');
    return (json as List).map((e) => RelayJob.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> report(String alertId, RelaySendOutcome outcome, String? error) =>
      _api.post('/relay/alerts/$alertId/result', {'outcome': outcome.wire, 'error': ?error});
}
