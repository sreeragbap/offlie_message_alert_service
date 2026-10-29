import 'package:equatable/equatable.dart';

enum AlertState {
  scheduled('SCHEDULED', 'Scheduled'),
  due('DUE', 'Ready to send'),
  sentFromDevice('SENT_FROM_DEVICE', 'Sent from your phone'),
  sending('SENDING', 'Sending'),
  smsAccepted('SMS_ACCEPTED', 'Accepted by SMS provider'),
  smsDelivered('SMS_DELIVERED', 'Delivered'),
  smsFailed('SMS_FAILED', 'Failed'),
  smsUnknown('SMS_UNKNOWN', 'Outcome unknown'),
  cancelled('CANCELLED', 'Cancelled'),
  skipped('SKIPPED', 'Skipped'),
  expired('EXPIRED', 'Expired'),
  unknown('UNKNOWN', 'Unknown');

  const AlertState(this.wire, this.label);
  final String wire;
  final String label;

  static AlertState parse(String? value) =>
      values.firstWhere((s) => s.wire == value, orElse: () => unknown);
}

/// Messaging platforms the user can pick as the place their message is waiting.
enum MessagingPlatform {
  whatsapp('WHATSAPP', 'WhatsApp'),
  telegram('TELEGRAM', 'Telegram'),
  messenger('MESSENGER', 'Messenger'),
  instagram('INSTAGRAM', 'Instagram'),
  signal('SIGNAL', 'Signal'),
  other('OTHER', 'Other');

  const MessagingPlatform(this.wire, this.label);
  final String wire;
  final String label;

  static MessagingPlatform parse(String? value) =>
      values.firstWhere((p) => p.wire == value, orElse: () => other);
}

class Alert extends Equatable {
  const Alert({
    required this.id,
    required this.recipientId,
    required this.recipientName,
    required this.recipientPhone,
    required this.platform,
    required this.channel,
    required this.state,
    required this.messageText,
    required this.dueAt,
    required this.createdAt,
    required this.completedAt,
    required this.deliveryConfirmed,
    required this.note,
  });

  final String id;
  final String? recipientId;
  final String? recipientName;
  final String? recipientPhone;
  final MessagingPlatform platform;
  final String channel;
  final AlertState state;
  final String messageText;
  final DateTime dueAt;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool deliveryConfirmed;
  final String? note;

  bool get isOpen => state == AlertState.scheduled || state == AlertState.due;

  bool get isDeviceChannel => channel == 'DEVICE_SMS';

  /// The user can open their SMS app for this alert (early sending is allowed).
  bool get canSendFromDevice => isOpen && isDeviceChannel && recipientPhone != null;

  factory Alert.fromJson(Map<String, dynamic> json) {
    final recipient = json['recipient'] as Map<String, dynamic>?;
    return Alert(
      id: json['id'] as String,
      recipientId: recipient?['id'] as String?,
      recipientName: recipient?['displayName'] as String?,
      recipientPhone: recipient?['phoneE164'] as String?,
      platform: MessagingPlatform.parse(json['platform'] as String?),
      channel: json['channel'] as String,
      state: AlertState.parse(json['state'] as String?),
      messageText: json['messageText'] as String,
      dueAt: DateTime.parse(json['dueAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
      deliveryConfirmed: json['deliveryConfirmed'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, state, dueAt, completedAt, recipientName, note];
}

class AlertPage extends Equatable {
  const AlertPage({required this.items, required this.page, required this.totalItems});

  final List<Alert> items;
  final int page;
  final int totalItems;

  factory AlertPage.fromJson(Map<String, dynamic> json) => AlertPage(
        items: (json['items'] as List).map((e) => Alert.fromJson(e as Map<String, dynamic>)).toList(),
        page: json['page'] as int,
        totalItems: (json['totalItems'] as num).toInt(),
      );

  @override
  List<Object?> get props => [items, page, totalItems];
}
