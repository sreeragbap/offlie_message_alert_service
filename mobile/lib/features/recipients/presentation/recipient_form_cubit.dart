import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/resource.dart';
import '../data/recipient.dart';
import '../data/recipient_repository.dart';

class RecipientFormState extends Equatable {
  const RecipientFormState({this.status = ActionStatus.idle, this.error, this.saved});

  final ActionStatus status;
  final String? error;
  final Recipient? saved;

  @override
  List<Object?> get props => [status, error, saved];
}

class RecipientFormCubit extends Cubit<RecipientFormState> {
  RecipientFormCubit(this._repository, {this.existing}) : super(const RecipientFormState());

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
