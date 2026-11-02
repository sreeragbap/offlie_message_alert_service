import 'package:equatable/equatable.dart';

class AlertPreferences extends Equatable {
  const AlertPreferences({
    required this.defaultDelayMinutes,
    required this.maxAlertsPerRecipientPerDay,
    required this.maxAlertsPerDay,
    required this.messageTemplate,
  });

  final int defaultDelayMinutes;
  final int maxAlertsPerRecipientPerDay;
  final int maxAlertsPerDay;
  final String messageTemplate;

  AlertPreferences copyWith({
    int? defaultDelayMinutes,
    int? maxAlertsPerRecipientPerDay,
    int? maxAlertsPerDay,
    String? messageTemplate,
  }) =>
      AlertPreferences(
        defaultDelayMinutes: defaultDelayMinutes ?? this.defaultDelayMinutes,
        maxAlertsPerRecipientPerDay: maxAlertsPerRecipientPerDay ?? this.maxAlertsPerRecipientPerDay,
        maxAlertsPerDay: maxAlertsPerDay ?? this.maxAlertsPerDay,
        messageTemplate: messageTemplate ?? this.messageTemplate,
      );

  factory AlertPreferences.fromJson(Map<String, dynamic> json) => AlertPreferences(
        defaultDelayMinutes: json['defaultDelayMinutes'] as int,
        maxAlertsPerRecipientPerDay: json['maxAlertsPerRecipientPerDay'] as int,
        maxAlertsPerDay: json['maxAlertsPerDay'] as int,
        messageTemplate: json['messageTemplate'] as String,
      );

  Map<String, dynamic> toJson() => {
        'defaultDelayMinutes': defaultDelayMinutes,
        'maxAlertsPerRecipientPerDay': maxAlertsPerRecipientPerDay,
        'maxAlertsPerDay': maxAlertsPerDay,
        'messageTemplate': messageTemplate,
      };

  @override
  List<Object?> get props =>
      [defaultDelayMinutes, maxAlertsPerRecipientPerDay, maxAlertsPerDay, messageTemplate];
}
