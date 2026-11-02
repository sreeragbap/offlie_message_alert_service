import 'package:offline_alert/features/whatsapp/domain/models/whatsapp_message.dart';
import 'package:offline_alert/features/whatsapp/domain/models/whatsapp_status.dart';

/// Contract `WhatsAppService` is registered under, so tests can fake it.
abstract class WhatsAppRepository {
  Future<WhatsAppStatus> status();

  Future<List<WaMessage>> recent({String? recipientId, int limit = 50});

  /// [clientRequestId] makes retries safe: the server returns the original message.
  Future<WaMessage> send({
    required String clientRequestId,
    required String recipientId,
    required String text,
    required bool smsAlert,
    required int alertAfterMinutes,
  });
}
