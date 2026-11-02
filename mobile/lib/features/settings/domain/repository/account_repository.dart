import 'package:offline_alert/features/settings/domain/models/profile.dart';

/// Contract `AccountService` is registered under, so tests can fake it.
abstract class AccountRepository {
  Future<Profile> load();

  Future<Profile> updateName(String displayName);

  /// Returns whether the sign-in account was also deleted (needs server configuration).
  Future<bool> deleteAccount();
}
