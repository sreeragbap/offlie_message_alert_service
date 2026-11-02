import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/bloc/resource.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/features/auth/domain/repository/auth_repository.dart';

part 'auth_form_state.dart';

@injectable
class AuthFormCubit extends Cubit<AuthFormState> {
  AuthFormCubit(this._auth) : super(const AuthFormState());

  final AuthRepository _auth;

  Future<void> signIn(String email, String password) => _run(() async {
        await _auth.signIn(email: email.trim(), password: password);
        return null;
      });

  Future<void> signUp(String email, String password) => _run(() async {
        final needsConfirmation = await _auth.signUp(email: email.trim(), password: password);
        return needsConfirmation
            ? 'Account created. Check your email to confirm it, then sign in.'
            : null;
      });

  Future<void> resetPassword(String email) => _run(() async {
        await _auth.sendPasswordReset(email.trim());
        return 'If an account exists for this email, a reset link is on its way.';
      });

  Future<void> _run(Future<String?> Function() action) async {
    emit(const AuthFormState(status: ActionStatus.working));
    try {
      final info = await action();
      emit(AuthFormState(status: ActionStatus.done, info: info));
    } on ApiException catch (e) {
      emit(AuthFormState(status: ActionStatus.failed, error: e.message));
    }
  }
}
