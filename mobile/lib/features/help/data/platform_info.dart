import 'package:equatable/equatable.dart';

import '../../../core/network/api_client.dart';

/// What a messaging platform really supports, as reported by the backend.
class PlatformInfo extends Equatable {
  const PlatformInfo({
    required this.id,
    required this.name,
    required this.manualAlerts,
    required this.automaticDetection,
    required this.automaticDetectionConnected,
    required this.explanation,
  });

  final String id;
  final String name;
  final bool manualAlerts;
  final String automaticDetection;
  final bool automaticDetectionConnected;
  final String explanation;

  String get automaticLabel => switch (automaticDetection) {
        'BUSINESS_ACCOUNTS_ONLY' => 'Business accounts only',
        _ => 'Not available',
      };

  factory PlatformInfo.fromJson(Map<String, dynamic> json) => PlatformInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        manualAlerts: json['manualAlerts'] as bool,
        automaticDetection: json['automaticDetection'] as String,
        automaticDetectionConnected: json['automaticDetectionConnected'] as bool,
        explanation: json['explanation'] as String,
      );

  @override
  List<Object?> get props => [id, automaticDetection, automaticDetectionConnected];
}

class PlatformRepository {
  PlatformRepository(this._api);

  final ApiClient _api;

  Future<List<PlatformInfo>> list() async {
    final json = await _api.get('/platforms') as List;
    return json.map((e) => PlatformInfo.fromJson(e as Map<String, dynamic>)).toList();
  }
}
