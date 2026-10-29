import 'package:flutter_test/flutter_test.dart';
import 'package:offline_alert/features/alerts/data/alert.dart';

import '../../fixtures.dart';

void main() {
  test('parses alert json', () {
    final a = alert();
    expect(a.state, AlertState.scheduled);
    expect(a.platform, MessagingPlatform.whatsapp);
    expect(a.recipientPhone, '+919876543210');
    expect(a.dueAt, DateTime.utc(2026, 10, 29, 10, 30));
  });

  test('unknown server values do not crash the app', () {
    expect(AlertState.parse('SOMETHING_NEW'), AlertState.unknown);
    expect(MessagingPlatform.parse('VIBER'), MessagingPlatform.other);
  });

  test('can only send open device alerts with a recipient', () {
    expect(alert(state: 'SCHEDULED').canSendFromDevice, isTrue);
    expect(alert(state: 'DUE').canSendFromDevice, isTrue);
    expect(alert(state: 'SENT_FROM_DEVICE').canSendFromDevice, isFalse);
    expect(alert(state: 'CANCELLED').canSendFromDevice, isFalse);
    expect(alert(state: 'DUE', withRecipient: false).canSendFromDevice, isFalse);
    expect(Alert.fromJson(alertJson(channel: 'SERVER_SMS')).canSendFromDevice, isFalse);
  });
}
