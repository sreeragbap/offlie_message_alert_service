import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/bloc/resource.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/core/notifications/alert_reminders.dart';
import 'package:offline_alert/features/alerts/domain/models/alert.dart';
import 'package:offline_alert/features/alerts/domain/repository/alert_repository.dart';
import 'package:offline_alert/features/preferences/domain/models/alert_preferences.dart';
import 'package:offline_alert/features/preferences/domain/repository/alert_preferences_repository.dart';
import 'package:offline_alert/features/recipients/domain/models/recipient.dart';
import 'package:offline_alert/features/recipients/domain/repository/recipient_repository.dart';
import 'package:uuid/uuid.dart';

part 'new_alert_state.dart';

@injectable
class NewAlertCubit extends Cubit<NewAlertState> {
  NewAlertCubit(this._recipients, this._preferences, this._alerts, this._reminders, {@factoryParam String? recipientId})
      : super(NewAlertState(recipientId: recipientId));

  final RecipientRepository _recipients;
  final AlertPreferencesRepository _preferences;
  final AlertRepository _alerts;
  final AlertReminders _reminders;
  final _uuid = const Uuid();

  /// One id per distinct request: retrying the same choice cannot create a duplicate,
  /// but changing the choice starts a new request.
  late String _requestId = _uuid.v4();

  Future<void> load() async {
    emit(state.copyWith(recipients: const Loading()));
    try {
      final results = await Future.wait([_recipients.list(), _preferences.load()]);
      final eligible = (results[0] as List<Recipient>).where((r) => r.canReceiveAlerts).toList();
      final prefs = results[1] as AlertPreferences;
      final selected = eligible.any((r) => r.id == state.recipientId)
          ? state.recipientId
          : (eligible.length == 1 ? eligible.first.id : null);
      emit(NewAlertState(
        recipients: Loaded(eligible),
        recipientId: selected,
        platform: state.platform,
        delayMinutes: prefs.defaultDelayMinutes,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(recipients: Failed(e)));
    }
  }

  void selectRecipient(String id) => _change(state.copyWith(recipientId: id));

  void selectPlatform(MessagingPlatform platform) => _change(state.copyWith(platform: platform));

  void selectDelay(int minutes) => _change(state.copyWith(delayMinutes: minutes));

  void _change(NewAlertState next) {
    _requestId = _uuid.v4();
    emit(next.copyWith(status: ActionStatus.idle));
  }

  Future<void> submit() async {
    final recipientId = state.recipientId;
    if (recipientId == null) return;
    emit(state.copyWith(status: ActionStatus.working));
    try {
      final alert = await _alerts.create(
        clientRequestId: _requestId,
        recipientId: recipientId,
        platform: state.platform,
        delayMinutes: state.delayMinutes,
      );
      if (alert.state == AlertState.scheduled) {
        await _reminders.requestPermission();
        await _reminders.schedule(alert);
      }
      emit(state.copyWith(status: ActionStatus.done, created: alert));
    } on ApiException catch (e) {
      emit(state.copyWith(status: ActionStatus.failed, error: e.message));
    }
  }
}
