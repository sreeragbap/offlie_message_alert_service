import 'package:equatable/equatable.dart';

import '../../../core/network/api_client.dart';

class Profile extends Equatable {
  const Profile({required this.email, required this.displayName});

  final String? email;
  final String? displayName;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      Profile(email: json['email'] as String?, displayName: json['displayName'] as String?);

  @override
  List<Object?> get props => [email, displayName];
}

class AccountRepository {
  AccountRepository(this._api);

  final ApiClient _api;

  Future<Profile> load() async => Profile.fromJson(await _api.get('/me') as Map<String, dynamic>);

  Future<Profile> updateName(String displayName) async =>
      Profile.fromJson(await _api.patch('/me', {'displayName': displayName}) as Map<String, dynamic>);

  /// Returns whether the sign-in account was also deleted (needs server configuration).
  Future<bool> deleteAccount() async {
    final json = await _api.delete('/me') as Map<String, dynamic>;
    return json['authAccountDeleted'] as bool? ?? false;
  }
}
