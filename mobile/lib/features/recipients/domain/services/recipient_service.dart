import 'package:injectable/injectable.dart';
import 'package:offline_alert/core/network/api_client.dart';
import 'package:offline_alert/features/recipients/domain/models/recipient.dart';
import 'package:offline_alert/features/recipients/domain/repository/recipient_repository.dart';

@LazySingleton(as: RecipientRepository)
class RecipientService implements RecipientRepository {
  RecipientService(this._api);

  final ApiClient _api;

  @override
  Future<List<Recipient>> list() async {
    final json = await _api.get('/recipients') as List;
    return json.map((e) => Recipient.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Recipient> get(String id) async =>
      Recipient.fromJson(await _api.get('/recipients/$id') as Map<String, dynamic>);

  @override
  Future<Recipient> create({required String displayName, required String phone}) async =>
      Recipient.fromJson(await _api.post('/recipients', {'displayName': displayName, 'phone': phone})
          as Map<String, dynamic>);

  @override
  Future<Recipient> update(String id,
      {String? displayName, String? phone, bool? alertsEnabled, bool? optedOut}) async {
    final body = <String, dynamic>{
      'displayName': ?displayName,
      'phone': ?phone,
      'alertsEnabled': ?alertsEnabled,
      'optedOut': ?optedOut,
    };
    return Recipient.fromJson(await _api.patch('/recipients/$id', body) as Map<String, dynamic>);
  }

  @override
  Future<void> delete(String id) => _api.delete('/recipients/$id');
}
