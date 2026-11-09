import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/bloc/resource.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/features/recipients/domain/models/auto_message.dart';
import 'package:offline_alert/features/recipients/domain/models/recipient.dart';
import 'package:offline_alert/features/recipients/domain/repository/recipient_repository.dart';

part 'recipient_form_state.dart';

@injectable
class RecipientFormCubit extends Cubit<RecipientFormState> {
  RecipientFormCubit(this._repository, {@factoryParam this.existing}) : super(const RecipientFormState());

  final RecipientRepository _repository;
  final Recipient? existing;

  /// Set when a new recipient was created but a later step failed, so retrying updates it
  /// instead of creating a duplicate.
  Recipient? _created;

  Future<void> loadAutoMessage() async {
    final current = existing;
    if (current == null) return;
    emit(state.copyWith(autoLoading: true, autoLoadError: () => null));
    try {
      final autoMessage = await _repository.getAutoMessage(current.id);
      emit(state.copyWith(autoMessage: autoMessage, autoLoading: false));
    } on ApiException catch (e) {
      emit(state.copyWith(autoLoading: false, autoLoadError: () => e.message));
    }
  }

  /// Saves the recipient, then the automatic message when its settings changed.
  Future<void> save({
    required String displayName,
    required String phone,
    required bool optedOut,
    AutoMessage? autoMessage,
  }) async {
    emit(state.copyWith(status: ActionStatus.working, error: () => null));
    try {
      final current = existing ?? _created;
      final saved = current == null
          ? await _repository.create(displayName: displayName.trim(), phone: phone.trim())
          : await _repository.update(
              current.id,
              displayName: displayName.trim(),
              phone: phone.trim() == current.phoneE164 ? null : phone.trim(),
              optedOut: optedOut,
            );
      if (existing == null) _created = saved;
      var savedAuto = state.autoMessage;
      if (autoMessage != null && _needsSave(autoMessage)) {
        savedAuto = await _repository.saveAutoMessage(saved.id, autoMessage);
      }
      emit(state.copyWith(status: ActionStatus.done, saved: saved, autoMessage: savedAuto));
    } on ApiException catch (e) {
      emit(state.copyWith(status: ActionStatus.failed, error: () => e.message));
    }
  }

  /// Changed settings are saved. An unchanged "Once" message is saved again (so it goes again a
  /// minute later, as the screen promises) unless it is still waiting to go.
  bool _needsSave(AutoMessage draft) {
    final saved = state.autoMessage;
    if (!draft.sameSettingsAs(saved)) return true;
    return draft.enabled && !draft.repeating && saved.nextRunAt == null;
  }
}
