part of 'whatsapp_compose_cubit.dart';

class WhatsAppComposeState extends Equatable {
  const WhatsAppComposeState({
    this.recipients = const Loading(),
    this.recipientId,
    this.text = '',
    this.smsAlert = true,
    this.alertAfterMinutes = 15,
    this.smsText = '',
    this.senderName,
    this.status = ActionStatus.idle,
    this.error,
    this.sent,
  });

  /// What the message box starts with; the server fills in {name} and {sender}.
  static const defaultText = 'Hi {name}, this is a message from {sender}.';

  static const maxSmsLength = 300;

  final Resource<List<Recipient>> recipients;
  final String? recipientId;
  final String text;
  final bool smsAlert;
  final int alertAfterMinutes;

  /// The SMS for this message. Starts as the default from alert preferences.
  final String smsText;

  /// The user's name for {sender} in the preview; null until loaded (the server uses "Someone").
  final String? senderName;
  final ActionStatus status;
  final String? error;
  final WaMessage? sent;

  bool get canSend =>
      recipientId != null &&
      text.trim().isNotEmpty &&
      (!smsAlert || (smsText.trim().isNotEmpty && smsText.trim().length <= maxSmsLength)) &&
      status != ActionStatus.working;

  /// The WhatsApp message as [recipient] will see it.
  String messagePreview(Recipient recipient) => text
      .trim()
      .replaceAll('{name}', recipient.displayName)
      .replaceAll('{sender}', senderName ?? 'Someone');

  /// The SMS as [recipient] will get it if WhatsApp does not deliver in time.
  String smsPreview(Recipient recipient) =>
      smsText.trim().replaceAll('{name}', recipient.displayName).replaceAll('{platform}', 'WhatsApp');

  WhatsAppComposeState copyWith({
    Resource<List<Recipient>>? recipients,
    String? recipientId,
    String? text,
    bool? smsAlert,
    int? alertAfterMinutes,
    String? smsText,
    String? senderName,
    ActionStatus? status,
    String? error,
    WaMessage? sent,
  }) => WhatsAppComposeState(
    recipients: recipients ?? this.recipients,
    recipientId: recipientId ?? this.recipientId,
    text: text ?? this.text,
    smsAlert: smsAlert ?? this.smsAlert,
    alertAfterMinutes: alertAfterMinutes ?? this.alertAfterMinutes,
    smsText: smsText ?? this.smsText,
    senderName: senderName ?? this.senderName,
    status: status ?? this.status,
    error: error,
    sent: sent ?? this.sent,
  );

  @override
  List<Object?> get props => [
    recipients,
    recipientId,
    text,
    smsAlert,
    alertAfterMinutes,
    smsText,
    senderName,
    status,
    error,
    sent,
  ];
}
