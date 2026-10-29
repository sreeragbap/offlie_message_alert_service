import 'package:equatable/equatable.dart';

import '../../../core/network/api_client.dart';

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

class AlertPreferencesRepository {
  AlertPreferencesRepository(this._api);

  final ApiClient _api;

  Future<AlertPreferences> load() async =>
      AlertPreferences.fromJson(await _api.get('/alert-preferences') as Map<String, dynamic>);

  Future<AlertPreferences> save(AlertPreferences p) async =>
      AlertPreferences.fromJson(await _api.put('/alert-preferences', p.toJson()) as Map<String, dynamic>);
}
