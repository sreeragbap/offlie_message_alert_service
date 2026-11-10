// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:offline_alert/core/device/screen_wake_lock.dart' as _i580;
import 'package:offline_alert/core/di/register_module.dart' as _i748;
import 'package:offline_alert/core/network/api_client.dart' as _i772;
import 'package:offline_alert/core/notifications/alert_reminders.dart' as _i442;
import 'package:offline_alert/core/router/app_router.dart' as _i22;
import 'package:offline_alert/core/sms/sms_composer.dart' as _i828;
import 'package:offline_alert/core/sms/sms_relay_channel.dart' as _i587;
import 'package:offline_alert/features/alerts/domain/repository/alert_repository.dart'
    as _i680;
import 'package:offline_alert/features/alerts/domain/services/alert_service.dart'
    as _i125;
import 'package:offline_alert/features/alerts/logic/alert_detail_cubit/alert_detail_cubit.dart'
    as _i12;
import 'package:offline_alert/features/alerts/logic/alert_history_cubit/alert_history_cubit.dart'
    as _i781;
import 'package:offline_alert/features/alerts/logic/new_alert_cubit/new_alert_cubit.dart'
    as _i259;
import 'package:offline_alert/features/auth/domain/repository/auth_repository.dart'
    as _i921;
import 'package:offline_alert/features/auth/domain/services/auth_service.dart'
    as _i105;
import 'package:offline_alert/features/auth/logic/auth_form_cubit/auth_form_cubit.dart'
    as _i652;
import 'package:offline_alert/features/auth/logic/session_cubit/session_cubit.dart'
    as _i110;
import 'package:offline_alert/features/dashboard/domain/repository/dashboard_repository.dart'
    as _i554;
import 'package:offline_alert/features/dashboard/domain/services/dashboard_service.dart'
    as _i459;
import 'package:offline_alert/features/dashboard/logic/dashboard_cubit/dashboard_cubit.dart'
    as _i530;
import 'package:offline_alert/features/help/domain/repository/platform_repository.dart'
    as _i144;
import 'package:offline_alert/features/help/domain/services/platform_service.dart'
    as _i643;
import 'package:offline_alert/features/preferences/domain/repository/alert_preferences_repository.dart'
    as _i1005;
import 'package:offline_alert/features/preferences/domain/services/alert_preferences_service.dart'
    as _i745;
import 'package:offline_alert/features/preferences/logic/preferences_cubit/preferences_cubit.dart'
    as _i82;
import 'package:offline_alert/features/recipients/domain/models/recipient.dart'
    as _i154;
import 'package:offline_alert/features/recipients/domain/repository/recipient_repository.dart'
    as _i273;
import 'package:offline_alert/features/recipients/domain/services/recipient_service.dart'
    as _i23;
import 'package:offline_alert/features/recipients/logic/recipient_form_cubit/recipient_form_cubit.dart'
    as _i122;
import 'package:offline_alert/features/recipients/logic/recipients_cubit/recipients_cubit.dart'
    as _i699;
import 'package:offline_alert/features/relay/domain/repository/relay_repository.dart'
    as _i1015;
import 'package:offline_alert/features/relay/domain/services/relay_service.dart'
    as _i734;
import 'package:offline_alert/features/relay/logic/relay_cubit/relay_cubit.dart'
    as _i574;
import 'package:offline_alert/features/settings/domain/repository/account_repository.dart'
    as _i666;
import 'package:offline_alert/features/settings/domain/services/account_service.dart'
    as _i401;
import 'package:offline_alert/features/whatsapp/domain/repository/whatsapp_repository.dart'
    as _i831;
import 'package:offline_alert/features/whatsapp/domain/services/whatsapp_service.dart'
    as _i816;
import 'package:offline_alert/features/whatsapp/logic/whatsapp_compose_cubit/whatsapp_compose_cubit.dart'
    as _i908;
import 'package:offline_alert/features/whatsapp/logic/whatsapp_cubit/whatsapp_cubit.dart'
    as _i332;
import 'package:supabase_flutter/supabase_flutter.dart' as _i454;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final registerModule = _$RegisterModule();
    gh.lazySingleton<_i580.ScreenWakeLock>(() => _i580.ScreenWakeLock());
    gh.lazySingleton<_i454.GoTrueClient>(() => registerModule.goTrueClient);
    await gh.lazySingletonAsync<_i442.AlertReminders>(
      () => _i442.AlertReminders.create(),
      preResolve: true,
    );
    gh.lazySingleton<_i828.SmsComposer>(() => const _i828.SmsComposer());
    gh.lazySingleton<_i587.SmsRelayChannel>(() => _i587.SmsRelayChannel());
    gh.lazySingleton<_i921.AuthRepository>(
      () => _i105.AuthService(gh<_i454.GoTrueClient>()),
    );
    gh.lazySingleton<_i772.ApiClient>(
      () => _i772.ApiClient.create(gh<_i454.GoTrueClient>()),
    );
    gh.factory<_i652.AuthFormCubit>(
      () => _i652.AuthFormCubit(gh<_i921.AuthRepository>()),
    );
    gh.lazySingleton<_i110.SessionCubit>(
      () => _i110.SessionCubit(gh<_i921.AuthRepository>()),
      dispose: (i) => i.close(),
    );
    gh.lazySingleton<_i1015.RelayRepository>(
      () => _i734.RelayService(gh<_i772.ApiClient>()),
    );
    gh.lazySingleton<_i680.AlertRepository>(
      () => _i125.AlertService(gh<_i772.ApiClient>()),
    );
    gh.lazySingleton<_i1005.AlertPreferencesRepository>(
      () => _i745.AlertPreferencesService(gh<_i772.ApiClient>()),
    );
    gh.factory<_i781.AlertHistoryCubit>(
      () => _i781.AlertHistoryCubit(gh<_i680.AlertRepository>()),
    );
    gh.lazySingleton<_i273.RecipientRepository>(
      () => _i23.RecipientService(gh<_i772.ApiClient>()),
    );
    gh.lazySingleton<_i22.AppRouter>(
      () => _i22.AppRouter(gh<_i110.SessionCubit>()),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i554.DashboardRepository>(
      () => _i459.DashboardService(gh<_i772.ApiClient>()),
    );
    gh.lazySingleton<_i666.AccountRepository>(
      () => _i401.AccountService(gh<_i772.ApiClient>()),
    );
    gh.lazySingleton<_i831.WhatsAppRepository>(
      () => _i816.WhatsAppService(gh<_i772.ApiClient>()),
    );
    gh.lazySingleton<_i144.PlatformRepository>(
      () => _i643.PlatformService(gh<_i772.ApiClient>()),
    );
    gh.factoryParam<_i908.WhatsAppComposeCubit, String?, dynamic>(
      (recipientId, _) => _i908.WhatsAppComposeCubit(
        gh<_i273.RecipientRepository>(),
        gh<_i1005.AlertPreferencesRepository>(),
        gh<_i831.WhatsAppRepository>(),
        gh<_i666.AccountRepository>(),
        recipientId: recipientId,
      ),
    );
    gh.factory<_i332.WhatsAppCubit>(
      () => _i332.WhatsAppCubit(gh<_i831.WhatsAppRepository>()),
    );
    gh.factoryParam<_i12.AlertDetailCubit, String, dynamic>(
      (alertId, _) => _i12.AlertDetailCubit(
        gh<_i680.AlertRepository>(),
        gh<_i442.AlertReminders>(),
        gh<_i828.SmsComposer>(),
        alertId,
      ),
    );
    gh.factory<_i82.PreferencesCubit>(
      () => _i82.PreferencesCubit(gh<_i1005.AlertPreferencesRepository>()),
    );
    gh.factoryParam<_i259.NewAlertCubit, String?, dynamic>(
      (recipientId, _) => _i259.NewAlertCubit(
        gh<_i273.RecipientRepository>(),
        gh<_i1005.AlertPreferencesRepository>(),
        gh<_i680.AlertRepository>(),
        gh<_i442.AlertReminders>(),
        recipientId: recipientId,
      ),
    );
    gh.factory<_i699.RecipientsCubit>(
      () => _i699.RecipientsCubit(gh<_i273.RecipientRepository>()),
    );
    gh.factory<_i574.RelayCubit>(
      () => _i574.RelayCubit(
        gh<_i1015.RelayRepository>(),
        gh<_i587.SmsRelayChannel>(),
        gh<_i580.ScreenWakeLock>(),
      ),
    );
    gh.factory<_i530.DashboardCubit>(
      () => _i530.DashboardCubit(
        gh<_i554.DashboardRepository>(),
        gh<_i680.AlertRepository>(),
        gh<_i442.AlertReminders>(),
      ),
    );
    gh.factoryParam<_i122.RecipientFormCubit, _i154.Recipient?, dynamic>(
      (existing, _) => _i122.RecipientFormCubit(
        gh<_i273.RecipientRepository>(),
        existing: existing,
      ),
    );
    return this;
  }
}

class _$RegisterModule extends _i748.RegisterModule {}
