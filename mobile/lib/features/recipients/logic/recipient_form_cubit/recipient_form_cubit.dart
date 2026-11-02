import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/bloc/resource.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/features/recipients/domain/models/recipient.dart';
import 'package:offline_alert/features/recipients/domain/repository/recipient_repository.dart';

part 'recipient_form_state.dart';

@injectable
class RecipientFormCubit extends Cubit<RecipientFormState> {
  RecipientFormCubit(this._repository, {@factoryParam this.existing}) : super(const RecipientFormState());

  final RecipientRepository _repository;
  final Recipient? existing;

  Future<void> save({required String displayName, required String phone, required bool optedOut}) async {
    emit(const RecipientFormState(status: ActionStatus.working));
    try {
      final current = existing;
      final saved = current == null
          ? await _repository.create(displayName: displayName.trim(), phone: phone.trim())
          : await _repository.update(
              current.id,
              displayName: displayName.trim(),
              phone: phone.trim() == current.phoneE164 ? null : phone.trim(),
              optedOut: optedOut,
            );
      emit(RecipientFormState(status: ActionStatus.done, saved: saved));
    } on ApiException catch (e) {
      emit(RecipientFormState(status: ActionStatus.failed, error: e.message));
    }
  }
}
