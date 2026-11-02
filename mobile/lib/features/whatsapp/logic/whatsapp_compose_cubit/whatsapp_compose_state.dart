part of 'whatsapp_compose_cubit.dart';

class WhatsAppComposeState extends Equatable {
  const WhatsAppComposeState({
    this.recipients = const Loading(),
    this.recipientId,
    this.text = '',
    this.smsAlert = true,
    this.alertAfterMinutes = 15,
    this.status = ActionStatus.idle,
    this.error,
    this.sent,
  });

  final Resource<List<Recipient>> recipients;
  final String? recipientId;
  final String text;
  final bool smsAlert;
  final int alertAfterMinutes;
  final ActionStatus status;
  final String? error;
  final WaMessage? sent;

  bool get canSend => recipientId != null && text.trim().isNotEmpty && status != ActionStatus.working;

  WhatsAppComposeState copyWith({
    Resource<List<Recipient>>? recipients,
    String? recipientId,
    String? text,
    bool? smsAlert,
    int? alertAfterMinutes,
    ActionStatus? status,
    String? error,
    WaMessage? sent,
  }) => WhatsAppComposeState(
    recipients: recipients ?? this.recipients,
    recipientId: recipientId ?? this.recipientId,
    text: text ?? this.text,
    smsAlert: smsAlert ?? this.smsAlert,
    alertAfterMinutes: alertAfterMinutes ?? this.alertAfterMinutes,
    status: status ?? this.status,
    error: error,
    sent: sent ?? this.sent,
  );

  @override
  List<Object?> get props => [recipients, recipientId, text, smsAlert, alertAfterMinutes, status, error, sent];
}
