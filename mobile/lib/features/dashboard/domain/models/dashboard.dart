import 'package:equatable/equatable.dart';
import 'package:offline_alert/features/alerts/domain/models/alert.dart';

class Dashboard extends Equatable {
  const Dashboard({
    required this.serviceActive,
    required this.recipientCount,
    required this.alertableRecipientCount,
    required this.openAlertCount,
    required this.recentAlerts,
    required this.automaticMonitoringConnected,
    required this.setupIssues,
  });

  final bool serviceActive;
  final int recipientCount;
  final int alertableRecipientCount;
  final int openAlertCount;
  final List<Alert> recentAlerts;
  final bool automaticMonitoringConnected;
  final List<String> setupIssues;

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        serviceActive: json['serviceActive'] as bool,
        recipientCount: (json['recipientCount'] as num).toInt(),
        alertableRecipientCount: (json['alertableRecipientCount'] as num).toInt(),
        openAlertCount: (json['openAlertCount'] as num).toInt(),
        recentAlerts: (json['recentAlerts'] as List)
            .map((e) => Alert.fromJson(e as Map<String, dynamic>))
            .toList(),
        automaticMonitoringConnected: json['automaticMonitoringConnected'] as bool,
        setupIssues: (json['setupIssues'] as List).cast<String>(),
      );

  @override
  List<Object?> get props =>
      [serviceActive, recipientCount, alertableRecipientCount, openAlertCount, recentAlerts, setupIssues];
}
