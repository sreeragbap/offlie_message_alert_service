import '../../../core/network/api_client.dart';
import 'recipient.dart';

class RecipientRepository {
  RecipientRepository(this._api);

  final ApiClient _api;

  Future<List<Recipient>> list() async {
    final json = await _api.get('/recipients') as List;
    return json.map((e) => Recipient.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Recipient> get(String id) async =>
      Recipient.fromJson(await _api.get('/recipients/$id') as Map<String, dynamic>);

  Future<Recipient> create({required String displayName, required String phone}) async =>
      Recipient.fromJson(await _api.post('/recipients', {'displayName': displayName, 'phone': phone})
          as Map<String, dynamic>);

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

  Future<void> delete(String id) => _api.delete('/recipients/$id');
}
