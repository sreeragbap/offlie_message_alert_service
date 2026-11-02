import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/network/api_client.dart';
import 'package:offline_alert/features/settings/domain/models/profile.dart';
import 'package:offline_alert/features/settings/domain/repository/account_repository.dart';

@LazySingleton(as: AccountRepository)
class AccountService implements AccountRepository {
  AccountService(this._api);

  final ApiClient _api;

  @override
  Future<Profile> load() async => Profile.fromJson(await _api.get('/me') as Map<String, dynamic>);

  @override
  Future<Profile> updateName(String displayName) async =>
      Profile.fromJson(await _api.patch('/me', {'displayName': displayName}) as Map<String, dynamic>);

  @override
  Future<bool> deleteAccount() async {
    final json = await _api.delete('/me') as Map<String, dynamic>;
    return json['authAccountDeleted'] as bool? ?? false;
  }
}
