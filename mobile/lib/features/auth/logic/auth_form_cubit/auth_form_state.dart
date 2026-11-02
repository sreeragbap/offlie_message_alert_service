part of 'auth_form_cubit.dart';

class AuthFormState extends Equatable {
  const AuthFormState({this.status = ActionStatus.idle, this.error, this.info});

  final ActionStatus status;
  final String? error;

  /// A non-error message, e.g. "check your email".
  final String? info;

  @override
  List<Object?> get props => [status, error, info];
}
