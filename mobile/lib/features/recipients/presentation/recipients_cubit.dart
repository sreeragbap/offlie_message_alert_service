import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/resource.dart';
import '../data/recipient.dart';
import '../data/recipient_repository.dart';

class RecipientsCubit extends Cubit<Resource<List<Recipient>>> {
  RecipientsCubit(this._repository) : super(const Loading());

  final RecipientRepository _repository;

  Future<void> load() async {
    if (state is! Loaded) emit(const Loading());
    try {
      emit(Loaded(await _repository.list()));
    } on ApiException catch (e) {
      emit(Failed(e));
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> setAlertsEnabled(Recipient recipient, bool enabled) =>
      _mutate(() => _repository.update(recipient.id, alertsEnabled: enabled));

  Future<String?> delete(Recipient recipient) => _mutate(() => _repository.delete(recipient.id));

  Future<String?> _mutate(Future<Object?> Function() action) async {
    try {
      await action();
      await load();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}
