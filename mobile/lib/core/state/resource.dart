import 'package:equatable/equatable.dart';

import '../network/api_exception.dart';

/// Loading / loaded / failed, used by every screen that loads data.
sealed class Resource<T> extends Equatable {
  const Resource();

  @override
  List<Object?> get props => [];
}

class Loading<T> extends Resource<T> {
  const Loading();
}

class Loaded<T> extends Resource<T> {
  const Loaded(this.data);
  final T data;

  @override
  List<Object?> get props => [data];
}

class Failed<T> extends Resource<T> {
  const Failed(this.error);
  final ApiException error;

  @override
  List<Object?> get props => [error.code, error.message];
}

/// Status of a one-off action such as saving a form.
enum ActionStatus { idle, working, done, failed }
