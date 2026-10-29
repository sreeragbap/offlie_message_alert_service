import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/notifications/alert_reminders.dart';
import '../../../core/state/resource.dart';
import '../../preferences/data/alert_preferences.dart';
import '../../recipients/data/recipient.dart';
import '../../recipients/data/recipient_repository.dart';
import '../data/alert.dart';
import '../data/alert_repository.dart';

class NewAlertState extends Equatable {
  const NewAlertState({
    this.recipients = const Loading(),
    this.recipientId,
    this.platform = MessagingPlatform.whatsapp,
    this.delayMinutes = 30,
    this.status = ActionStatus.idle,
    this.error,
    this.created,
  });

  final Resource<List<Recipient>> recipients;
  final String? recipientId;
  final MessagingPlatform platform;
  final int delayMinutes;
  final ActionStatus status;
  final String? error;
  final Alert? created;

  bool get canSubmit => recipientId != null && status != ActionStatus.working;

  NewAlertState copyWith({
    Resource<List<Recipient>>? recipients,
    String? recipientId,
    MessagingPlatform? platform,
    int? delayMinutes,
    ActionStatus? status,
    String? error,
    Alert? created,
  }) =>
      NewAlertState(
        recipients: recipients ?? this.recipients,
        recipientId: recipientId ?? this.recipientId,
        platform: platform ?? this.platform,
        delayMinutes: delayMinutes ?? this.delayMinutes,
        status: status ?? this.status,
        error: error,
        created: created ?? this.created,
      );

  @override
  List<Object?> get props => [recipients, recipientId, platform, delayMinutes, status, error, created];
}

class NewAlertCubit extends Cubit<NewAlertState> {
  NewAlertCubit(this._recipients, this._preferences, this._alerts, this._reminders, {String? recipientId})
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
