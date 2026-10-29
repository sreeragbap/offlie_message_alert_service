import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/state/resource.dart';
import '../data/alert_preferences.dart';

class PreferencesState extends Equatable {
  const PreferencesState({this.preferences = const Loading(), this.status = ActionStatus.idle, this.error});

  final Resource<AlertPreferences> preferences;
  final ActionStatus status;
  final String? error;

  @override
  List<Object?> get props => [preferences, status, error];
}

class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit(this._repository) : super(const PreferencesState());

  final AlertPreferencesRepository _repository;

  Future<void> load() async {
    emit(const PreferencesState());
    try {
      emit(PreferencesState(preferences: Loaded(await _repository.load())));
    } on ApiException catch (e) {
      emit(PreferencesState(preferences: Failed(e)));
    }
  }

  Future<void> save(AlertPreferences preferences) async {
    emit(PreferencesState(preferences: state.preferences, status: ActionStatus.working));
    try {
      final saved = await _repository.save(preferences);
      emit(PreferencesState(preferences: Loaded(saved), status: ActionStatus.done));
    } on ApiException catch (e) {
      emit(PreferencesState(preferences: state.preferences, status: ActionStatus.failed, error: e.message));
    }
  }
}
