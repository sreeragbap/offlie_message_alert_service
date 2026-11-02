import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/network/api_client.dart';
import 'package:offline_alert/features/preferences/domain/models/alert_preferences.dart';
import 'package:offline_alert/features/preferences/domain/repository/alert_preferences_repository.dart';

@LazySingleton(as: AlertPreferencesRepository)
class AlertPreferencesService implements AlertPreferencesRepository {
  AlertPreferencesService(this._api);

  final ApiClient _api;

  @override
  Future<AlertPreferences> load() async =>
      AlertPreferences.fromJson(await _api.get('/alert-preferences') as Map<String, dynamic>);

  @override
  Future<AlertPreferences> save(AlertPreferences p) async =>
      AlertPreferences.fromJson(await _api.put('/alert-preferences', p.toJson()) as Map<String, dynamic>);
}
