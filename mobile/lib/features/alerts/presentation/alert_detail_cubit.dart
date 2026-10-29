import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/notifications/alert_reminders.dart';
import '../../../core/sms/sms_composer.dart';
import '../../../core/state/resource.dart';
import '../data/alert.dart';
import '../data/alert_repository.dart';

class AlertDetailState extends Equatable {
  const AlertDetailState({this.alert = const Loading(), this.busy = false, this.error});

  final Resource<Alert> alert;
  final bool busy;
  final String? error;

  @override
  List<Object?> get props => [alert, busy, error];
}

class AlertDetailCubit extends Cubit<AlertDetailState> {
  AlertDetailCubit(this._alerts, this._reminders, this._composer, this.alertId)
      : super(const AlertDetailState());

  final AlertRepository _alerts;
  final AlertReminders _reminders;
  final SmsComposer _composer;
  final String alertId;

  Future<void> load() async {
    try {
      emit(AlertDetailState(alert: Loaded(await _alerts.get(alertId))));
    } on ApiException catch (e) {
      emit(AlertDetailState(alert: Failed(e)));
    }
  }

  /// Opens the phone's SMS app. Returns false if no SMS app could be opened.
  Future<bool> openSmsApp() async {
    final current = state.alert;
    if (current is! Loaded<Alert> || !current.data.canSendFromDevice) return false;
    final alert = current.data;
    final opened = await _composer.open(phoneE164: alert.recipientPhone!, body: alert.messageText);
    if (!opened) {
      emit(AlertDetailState(alert: current, error: 'No SMS app found on this device.'));
    }
    return opened;
  }

  /// The user told us they sent the SMS. The phone cannot confirm delivery.
  Future<void> confirmSent() => _act((id) => _alerts.markSentFromDevice(id));

  Future<void> cancel() => _act((id) => _alerts.cancel(id));

  Future<void> _act(Future<Alert> Function(String id) action) async {
    final current = state.alert;
    emit(AlertDetailState(alert: current, busy: true));
    try {
      final updated = await action(alertId);
      await _reminders.cancel(alertId);
      emit(AlertDetailState(alert: Loaded(updated)));
    } on ApiException catch (e) {
      emit(AlertDetailState(alert: current, error: e.message));
    }
  }
}
