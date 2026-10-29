import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_exception.dart';

/// Wraps Supabase Auth. Only sign-in lives in Supabase on the client;
/// all app data goes through the backend.
class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  bool get isSignedIn => _auth.currentSession != null;

  String? get accessToken => _auth.currentSession?.accessToken;

  Stream<bool> get signedInChanges => _auth.onAuthStateChange.map((s) => s.session != null);

  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  /// Returns true when the user must confirm their email before signing in.
  Future<bool> signUp({required String email, required String password}) async {
    final response = await _guard(() => _auth.signUp(email: email, password: password));
    return response.session == null;
  }

  Future<void> sendPasswordReset(String email) => _guard(() => _auth.resetPasswordForEmail(email));

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
