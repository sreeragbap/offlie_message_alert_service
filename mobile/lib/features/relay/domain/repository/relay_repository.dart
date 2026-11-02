import 'package:offline_alert/core/sms/sms_relay_channel.dart';
import 'package:offline_alert/features/relay/domain/models/relay_job.dart';

/// Contract `RelayService` is registered under, so tests can fake it.
abstract class RelayRepository {
  /// Claims due SMS jobs. Each one is leased to this phone for two minutes.
  Future<List<RelayJob>> claim();

  Future<void> report(String alertId, RelaySendOutcome outcome, String? error);
}
