import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/network/api_client.dart';
import 'package:offline_alert/features/whatsapp/domain/models/whatsapp_message.dart';
import 'package:offline_alert/features/whatsapp/domain/models/whatsapp_status.dart';
import 'package:offline_alert/features/whatsapp/domain/repository/whatsapp_repository.dart';

@LazySingleton(as: WhatsAppRepository)
class WhatsAppService implements WhatsAppRepository {
  WhatsAppService(this._api);

  final ApiClient _api;

  @override
  Future<WhatsAppStatus> status() async {
    final json = await _api.get('/whatsapp/status') as Map<String, dynamic>;
    return WhatsAppStatus(connected: json['connected'] as bool, templateName: json['templateName'] as String?);
  }

  @override
  Future<List<WaMessage>> recent({String? recipientId, int limit = 50}) async {
    final json = await _api.get('/whatsapp/messages', query: {'limit': limit, 'recipientId': ?recipientId});
    return (json as List).map((e) => WaMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<WaMessage> send({
    required String clientRequestId,
    required String recipientId,
    required String text,
    required bool smsAlert,
    required int alertAfterMinutes,
  }) async {
    final json = await _api.post('/whatsapp/messages', {
      'clientRequestId': clientRequestId,
      'recipientId': recipientId,
      'text': text,
      'smsAlert': smsAlert,
      'alertAfterMinutes': alertAfterMinutes,
    });
    return WaMessage.fromJson(json as Map<String, dynamic>);
  }
}
