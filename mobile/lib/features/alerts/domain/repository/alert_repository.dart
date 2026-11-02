import 'package:offline_alert/features/alerts/domain/models/alert.dart';

/// Contract `AlertService` is registered under, so tests can fake it.
abstract class AlertRepository {
  /// [clientRequestId] makes retries safe: the server returns the original alert.
  Future<Alert> create({
    required String clientRequestId,
    required String recipientId,
    required MessagingPlatform platform,
    required int delayMinutes,
  });

  Future<Alert> get(String id);

  Future<AlertPage> list({int page = 0, int size = 20, bool openOnly = false});

  Future<Alert> cancel(String id);

  Future<Alert> markSentFromDevice(String id);
}
