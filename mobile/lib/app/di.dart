import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/notifications/alert_reminders.dart';
import '../features/alerts/data/alert_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/session_cubit.dart';
import '../features/dashboard/data/dashboard.dart';
import '../features/help/data/platform_info.dart';
import '../features/preferences/data/alert_preferences.dart';
import '../features/recipients/data/recipient_repository.dart';
import '../features/settings/data/account_repository.dart';

Future<void> setupDependencies() async {
  final getIt = GetIt.I;
  final auth = AuthRepository(Supabase.instance.client.auth);
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl, accessToken: () => auth.accessToken);
  final reminders = AlertReminders();
  await reminders.init();

  getIt
    ..registerSingleton<AuthRepository>(auth)
    ..registerSingleton<SessionCubit>(SessionCubit(auth))
    ..registerSingleton<ApiClient>(api)
    ..registerSingleton<AlertReminders>(reminders)
    ..registerLazySingleton(() => RecipientRepository(api))
    ..registerLazySingleton(() => AlertRepository(api))
    ..registerLazySingleton(() => AlertPreferencesRepository(api))
    ..registerLazySingleton(() => DashboardRepository(api))
    ..registerLazySingleton(() => PlatformRepository(api))
    ..registerLazySingleton(() => AccountRepository(api));
}
