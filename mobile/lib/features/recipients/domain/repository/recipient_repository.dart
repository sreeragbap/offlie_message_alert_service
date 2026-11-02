import 'package:offline_alert/features/recipients/domain/models/recipient.dart';

/// Contract `RecipientService` is registered under, so tests can fake it.
abstract class RecipientRepository {
  Future<List<Recipient>> list();

  Future<Recipient> get(String id);

  Future<Recipient> create({required String displayName, required String phone});

  /// Only the fields given are changed.
  Future<Recipient> update(String id, {String? displayName, String? phone, bool? alertsEnabled, bool? optedOut});

  Future<void> delete(String id);
}
