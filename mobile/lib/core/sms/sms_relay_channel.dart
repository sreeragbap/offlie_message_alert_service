import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What Android reported for an SMS sent in relay mode. The names match the backend's relay API.
enum RelaySendOutcome {
  sent('SENT'),
  retryableFailure('RETRYABLE_FAILURE'),
  failed('FAILED'),
  unknown('UNKNOWN');

  const RelaySendOutcome(this.wire);
  final String wire;

  static RelaySendOutcome parse(String? value) => values.firstWhere((o) => o.wire == value, orElse: () => unknown);
}

class RelaySendResult {
  const RelaySendResult(this.outcome, [this.error]);
  final RelaySendOutcome outcome;
  final String? error;
}

/// Sends an SMS from this phone's SIM without opening the messaging app (Android only,
/// needs the SEND_SMS permission). Implemented in android/.../SmsRelay.kt.
class SmsRelayChannel {
  static const _channel = MethodChannel('oma/sms_relay');

  bool get supported => !kIsWeb && Platform.isAndroid;

  /// Asks for SEND_SMS if needed; true when granted.
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<RelaySendResult> send({required String to, required String text, required String reference}) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('send', {
        'to': to,
        'text': text,
        'reference': reference,
      });
      return RelaySendResult(RelaySendOutcome.parse(result?['outcome'] as String?), result?['error'] as String?);
    } on PlatformException catch (e) {
      // We cannot tell how far it got; never let the backend retry it.
      return RelaySendResult(RelaySendOutcome.unknown, e.message);
    }
  }
}
