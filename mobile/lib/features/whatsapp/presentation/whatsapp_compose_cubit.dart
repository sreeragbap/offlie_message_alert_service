import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/resource.dart';
import '../../preferences/data/alert_preferences.dart';
import '../../recipients/data/recipient.dart';
import '../../recipients/data/recipient_repository.dart';
import '../data/whatsapp_message.dart';

class WhatsAppComposeState extends Equatable {
  const WhatsAppComposeState({
    this.recipients = const Loading(),
    this.recipientId,
    this.text = '',
    this.smsAlert = true,
    this.alertAfterMinutes = 15,
    this.status = ActionStatus.idle,
    this.error,
    this.sent,
  });

  final Resource<List<Recipient>> recipients;
  final String? recipientId;
  final String text;
  final bool smsAlert;
  final int alertAfterMinutes;
  final ActionStatus status;
  final String? error;
  final WaMessage? sent;

  bool get canSend => recipientId != null && text.trim().isNotEmpty && status != ActionStatus.working;

  WhatsAppComposeState copyWith({
    Resource<List<Recipient>>? recipients,
    String? recipientId,
    String? text,
    bool? smsAlert,
    int? alertAfterMinutes,
    ActionStatus? status,
    String? error,
    WaMessage? sent,
  }) => WhatsAppComposeState(
    recipients: recipients ?? this.recipients,
    recipientId: recipientId ?? this.recipientId,
    text: text ?? this.text,
    smsAlert: smsAlert ?? this.smsAlert,
    alertAfterMinutes: alertAfterMinutes ?? this.alertAfterMinutes,
    status: status ?? this.status,
    error: error,
    sent: sent ?? this.sent,
  );

  @override
  List<Object?> get props => [recipients, recipientId, text, smsAlert, alertAfterMinutes, status, error, sent];
}

class WhatsAppComposeCubit extends Cubit<WhatsAppComposeState> {
  WhatsAppComposeCubit(this._recipients, this._preferences, this._whatsApp, {String? recipientId})
    : super(WhatsAppComposeState(recipientId: recipientId));

  final RecipientRepository _recipients;
  final AlertPreferencesRepository _preferences;
  final WhatsAppRepository _whatsApp;
  final _uuid = const Uuid();

  /// Reused while the message is unchanged, so retrying after a network error cannot send twice.
  late String _requestId = _uuid.v4();

  Future<void> load() async {
    emit(state.copyWith(recipients: const Loading()));
    try {
      final results = await Future.wait([_recipients.list(), _preferences.load()]);
      final recipients = results[0] as List<Recipient>;
      final delay = (results[1] as AlertPreferences).defaultDelayMinutes;
      final selected = recipients.any((r) => r.id == state.recipientId)
          ? state.recipientId
          : (recipients.length == 1 ? recipients.first.id : null);
      emit(
        state.copyWith(
          recipients: Loaded(recipients),
          recipientId: selected,
          alertAfterMinutes: delay < 5 ? 15 : delay,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(recipients: Failed(e)));
    }
  }

  void selectRecipient(String id) => _change(state.copyWith(recipientId: id));

  void setText(String text) => _change(state.copyWith(text: text));

  void setSmsAlert(bool on) => _change(state.copyWith(smsAlert: on));

  void setAlertAfter(int minutes) => _change(state.copyWith(alertAfterMinutes: minutes));

  void _change(WhatsAppComposeState next) {
    _requestId = _uuid.v4();
    emit(next.copyWith(status: ActionStatus.idle));
  }

  Future<void> send() async {
    final recipientId = state.recipientId;
    if (!state.canSend || recipientId == null) return;
    emit(state.copyWith(status: ActionStatus.working));
    try {
      final message = await _whatsApp.send(
        clientRequestId: _requestId,
        recipientId: recipientId,
        text: state.text.trim(),
        smsAlert: state.smsAlert,
        alertAfterMinutes: state.alertAfterMinutes,
      );
      if (message.status == WaStatus.failed || message.status == WaStatus.unknown) {
        // WhatsApp answered (or did not); trying again is a new, deliberate send.
        _requestId = _uuid.v4();
        emit(state.copyWith(status: ActionStatus.failed, error: message.error ?? 'WhatsApp did not send it.'));
        return;
      }
      emit(state.copyWith(status: ActionStatus.done, sent: message));
    } on ApiException catch (e) {
      emit(state.copyWith(status: ActionStatus.failed, error: e.message));
    }
  }
}
