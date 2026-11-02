import 'package:equatable/equatable.dart';

class Recipient extends Equatable {
  const Recipient({
    required this.id,
    required this.displayName,
    required this.phoneE164,
    required this.alertsEnabled,
    required this.optedOut,
  });

  final String id;
  final String displayName;
  final String phoneE164;
  final bool alertsEnabled;
  final bool optedOut;

  bool get canReceiveAlerts => alertsEnabled && !optedOut;

  factory Recipient.fromJson(Map<String, dynamic> json) => Recipient(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        phoneE164: json['phoneE164'] as String,
        alertsEnabled: json['alertsEnabled'] as bool,
        optedOut: json['optedOut'] as bool,
      );

  @override
  List<Object?> get props => [id, displayName, phoneE164, alertsEnabled, optedOut];
}
