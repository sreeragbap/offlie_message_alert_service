import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/bloc/resource.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/features/preferences/domain/models/alert_preferences.dart';
import 'package:offline_alert/features/preferences/domain/repository/alert_preferences_repository.dart';

part 'preferences_state.dart';

@injectable
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
