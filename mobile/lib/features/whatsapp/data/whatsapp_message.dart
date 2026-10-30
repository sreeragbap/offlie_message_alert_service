import 'package:equatable/equatable.dart';

import '../../../core/network/api_client.dart';
import '../../alerts/data/alert.dart';

enum WaStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  sent('SENT'),
  delivered('DELIVERED'),
  read('READ'),
  failed('FAILED'),
  unknown('UNKNOWN'),
  received('RECEIVED');

  const WaStatus(this.wire);
  final String wire;

  static WaStatus parse(String? value) => values.firstWhere((s) => s.wire == value, orElse: () => unknown);
}

/// The SMS alert attached to a WhatsApp message.
class WaAlert extends Equatable {
  const WaAlert({required this.id, required this.state, required this.dueAt, this.note});

  final String id;
  final AlertState state;
  final DateTime? dueAt;
  final String? note;

  factory WaAlert.fromJson(Map<String, dynamic> json) => WaAlert(
    id: json['id'] as String,
    state: AlertState.parse(json['state'] as String?),
    dueAt: json['dueAt'] == null ? null : DateTime.parse(json['dueAt'] as String),
    note: json['note'] as String?,
  );

  @override
  List<Object?> get props => [id, state, dueAt, note];
}

class WaMessage extends Equatable {
  const WaMessage({
    required this.id,
    required this.recipientId,
    required this.recipientName,
    required this.incoming,
    required this.usedTemplate,
    required this.text,
    required this.status,
    required this.error,
    required this.createdAt,
    required this.alert,
    required this.alertSkipped,
  });

  final String id;
  final String? recipientId;
  final String? recipientName;
  final bool incoming;
  final bool usedTemplate;
  final String? text;
  final WaStatus status;
  final String? error;
  final DateTime createdAt;
  final WaAlert? alert;
  final String? alertSkipped;

  factory WaMessage.fromJson(Map<String, dynamic> json) => WaMessage(
    id: json['id'] as String,
    recipientId: json['recipientId'] as String?,
    recipientName: json['recipientName'] as String?,
    incoming: json['direction'] == 'IN',
    usedTemplate: json['kind'] == 'TEMPLATE',
    text: json['text'] as String?,
    status: WaStatus.parse(json['status'] as String?),
    error: json['error'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    alert: json['alert'] == null ? null : WaAlert.fromJson(json['alert'] as Map<String, dynamic>),
    alertSkipped: json['alertSkipped'] as String?,
  );

  @override
  List<Object?> get props => [id, status, error, alert, alertSkipped];
}

class WhatsAppStatus extends Equatable {
  const WhatsAppStatus({required this.connected, this.templateName});

  final bool connected;
  final String? templateName;

  @override
  List<Object?> get props => [connected, templateName];
}

class WhatsAppRepository {
  WhatsAppRepository(this._api);

  final ApiClient _api;

  Future<WhatsAppStatus> status() async {
    final json = await _api.get('/whatsapp/status') as Map<String, dynamic>;
    return WhatsAppStatus(connected: json['connected'] as bool, templateName: json['templateName'] as String?);
  }

  Future<List<WaMessage>> recent({String? recipientId, int limit = 50}) async {
    final json = await _api.get('/whatsapp/messages', query: {'limit': limit, 'recipientId': ?recipientId});
    return (json as List).map((e) => WaMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [clientRequestId] makes retries safe: the server returns the original message.
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
