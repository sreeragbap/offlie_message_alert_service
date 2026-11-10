import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/bloc/resource.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/features/preferences/domain/models/alert_preferences.dart';
import 'package:offline_alert/features/preferences/domain/repository/alert_preferences_repository.dart';
import 'package:offline_alert/features/recipients/domain/models/recipient.dart';
import 'package:offline_alert/features/recipients/domain/repository/recipient_repository.dart';
import 'package:offline_alert/features/settings/domain/repository/account_repository.dart';
import 'package:offline_alert/features/whatsapp/domain/models/whatsapp_message.dart';
import 'package:offline_alert/features/whatsapp/domain/repository/whatsapp_repository.dart';
import 'package:uuid/uuid.dart';

part 'whatsapp_compose_state.dart';

@injectable
class WhatsAppComposeCubit extends Cubit<WhatsAppComposeState> {
  WhatsAppComposeCubit(
    this._recipients,
    this._preferences,
    this._whatsApp,
    this._account, {
    @factoryParam String? recipientId,
  }) : super(WhatsAppComposeState(recipientId: recipientId));

  final RecipientRepository _recipients;
  final AlertPreferencesRepository _preferences;
  final WhatsAppRepository _whatsApp;
  final AccountRepository _account;
  final _uuid = const Uuid();

  /// Reused while the message is unchanged, so retrying after a network error cannot send twice.
  late String _requestId = _uuid.v4();

  /// Loads recipients and fills the message and the SMS with their defaults (unless already edited).
  Future<void> load() async {
    emit(state.copyWith(recipients: const Loading()));
    final senderName = _senderName();
    try {
      final results = await Future.wait([_recipients.list(), _preferences.load()]);
      final recipients = results[0] as List<Recipient>;
      final preferences = results[1] as AlertPreferences;
      final delay = preferences.defaultDelayMinutes;
      final selected = recipients.any((r) => r.id == state.recipientId)
          ? state.recipientId
          : (recipients.length == 1 ? recipients.first.id : null);
      emit(
        state.copyWith(
          recipients: Loaded(recipients),
          recipientId: selected,
          alertAfterMinutes: delay < 5 ? 15 : delay,
          text: state.text.isEmpty ? WhatsAppComposeState.defaultText : null,
          smsText: state.smsText.isEmpty ? preferences.messageTemplate : null,
          senderName: await senderName,
        ),
      );
    } on ApiException catch (e) {
      emit(state.copyWith(recipients: Failed(e)));
    }
  }

  /// Only for the preview, so a failure just leaves {sender} as the server's fallback.
  Future<String?> _senderName() async {
    try {
      final name = (await _account.load()).displayName?.trim();
      return name == null || name.isEmpty ? null : name;
    } on Exception {
      return null;
    }
  }

  void selectRecipient(String id) => _change(state.copyWith(recipientId: id));

  void setText(String text) => _change(state.copyWith(text: text));

  void setSmsAlert(bool on) => _change(state.copyWith(smsAlert: on));

  void setSmsText(String text) => _change(state.copyWith(smsText: text));

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
        smsText: state.smsAlert ? state.smsText.trim() : null,
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
