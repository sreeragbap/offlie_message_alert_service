import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/network/api_client.dart';
import 'package:offline_alert/features/alerts/domain/models/alert.dart';
import 'package:offline_alert/features/alerts/domain/repository/alert_repository.dart';

@LazySingleton(as: AlertRepository)
class AlertService implements AlertRepository {
  AlertService(this._api);

  final ApiClient _api;

  @override
  Future<Alert> create({
    required String clientRequestId,
    required String recipientId,
    required MessagingPlatform platform,
    required int delayMinutes,
  }) async {
    final json = await _api.post('/alerts', {
      'clientRequestId': clientRequestId,
      'recipientId': recipientId,
      'platform': platform.wire,
      'delayMinutes': delayMinutes,
    });
    return Alert.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Alert> get(String id) async =>
      Alert.fromJson(await _api.get('/alerts/$id') as Map<String, dynamic>);

  @override
  Future<AlertPage> list({int page = 0, int size = 20, bool openOnly = false}) async {
    final json = await _api.get('/alerts', query: {'page': page, 'size': size, 'openOnly': openOnly});
    return AlertPage.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Alert> cancel(String id) async =>
      Alert.fromJson(await _api.post('/alerts/$id/cancel') as Map<String, dynamic>);

  @override
  Future<Alert> markSentFromDevice(String id) async =>
      Alert.fromJson(await _api.post('/alerts/$id/sent-from-device') as Map<String, dynamic>);
}
