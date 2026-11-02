part of 'preferences_cubit.dart';

class PreferencesState extends Equatable {
  const PreferencesState({this.preferences = const Loading(), this.status = ActionStatus.idle, this.error});

  final Resource<AlertPreferences> preferences;
  final ActionStatus status;
  final String? error;

  @override
  List<Object?> get props => [preferences, status, error];
}
