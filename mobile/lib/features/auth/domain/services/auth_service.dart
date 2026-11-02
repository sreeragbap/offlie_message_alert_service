import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/features/auth/domain/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wraps Supabase Auth.
@LazySingleton(as: AuthRepository)
class AuthService implements AuthRepository {
  AuthService(this._auth);

  final GoTrueClient _auth;

  @override
  bool get isSignedIn => _auth.currentSession != null;

  @override
  String? get accessToken => _auth.currentSession?.accessToken;

  @override
  Stream<bool> get signedInChanges => _auth.onAuthStateChange.map((s) => s.session != null);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  @override
  Future<bool> signUp({required String email, required String password}) async {
    final response = await _guard(() => _auth.signUp(email: email, password: password));
    return response.session == null;
  }

  @override
  Future<void> sendPasswordReset(String email) => _guard(() => _auth.resetPasswordForEmail(email));

  @override
  Future<void> signOut() => _auth.signOut();

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw ApiException('AUTH_${e.statusCode ?? 'ERROR'}', e.message);
    } catch (_) {
      throw ApiException.network;
    }
  }
}
