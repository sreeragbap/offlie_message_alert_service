import 'package:offline_alert/features/preferences/domain/models/alert_preferences.dart';

/// Contract `AlertPreferencesService` is registered under, so tests can fake it.
abstract class AlertPreferencesRepository {
  Future<AlertPreferences> load();

  Future<AlertPreferences> save(AlertPreferences p);
}
