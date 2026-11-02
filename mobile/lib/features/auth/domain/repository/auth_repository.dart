/// Contract `AuthService` is registered under. Only sign-in lives in Supabase
/// on the client; all app data goes through the backend.
abstract class AuthRepository {
  bool get isSignedIn;

  String? get accessToken;

  Stream<bool> get signedInChanges;

  Future<void> signIn({required String email, required String password});

  /// Returns true when the user must confirm their email before signing in.
  Future<bool> signUp({required String email, required String password});

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}
