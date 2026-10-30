import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/core/state/resource.dart';
import 'package:offline_alert/features/preferences/data/alert_preferences.dart';
import 'package:offline_alert/features/recipients/data/recipient_repository.dart';
import 'package:offline_alert/features/whatsapp/data/whatsapp_message.dart';
import 'package:offline_alert/features/whatsapp/presentation/whatsapp_compose_cubit.dart';
import 'package:offline_alert/features/whatsapp/presentation/whatsapp_message_tile.dart';

import '../../fixtures.dart';

class _Recipients extends Mock implements RecipientRepository {}

class _Preferences extends Mock implements AlertPreferencesRepository {}

class _WhatsApp extends Mock implements WhatsAppRepository {}

const _prefs = AlertPreferences(
  defaultDelayMinutes: 30,
  maxAlertsPerRecipientPerDay: 3,
  maxAlertsPerDay: 20,
  messageTemplate: 'Hi {name}',
);

WaMessage message({String status = 'ACCEPTED', Map<String, dynamic>? alert, String? skipped, String? error}) =>
    WaMessage.fromJson({
      'id': 'm1',
      'recipientId': 'r1',
      'recipientName': 'Anu',
      'direction': 'OUT',
      'kind': 'TEMPLATE',
      'text': 'Hello',
      'status': status,
      'error': error,
      'createdAt': '2026-10-30T10:00:00Z',
      'alert': alert,
      'alertSkipped': skipped,
    });

void main() {
  late _Recipients recipients;
  late _Preferences preferences;
  late _WhatsApp whatsApp;
  final requestIds = <String>[];

  setUp(() {
    recipients = _Recipients();
    preferences = _Preferences();
    whatsApp = _WhatsApp();
    requestIds.clear();
    when(() => recipients.list()).thenAnswer((_) async => [anu]);
    when(() => preferences.load()).thenAnswer((_) async => _prefs);
  });

  void sendAnswers(Future<WaMessage> Function() answer) {
    when(
      () => whatsApp.send(
        clientRequestId: any(named: 'clientRequestId'),
        recipientId: any(named: 'recipientId'),
        text: any(named: 'text'),
        smsAlert: any(named: 'smsAlert'),
        alertAfterMinutes: any(named: 'alertAfterMinutes'),
      ),
    ).thenAnswer((invocation) {
      requestIds.add(invocation.namedArguments[#clientRequestId] as String);
      return answer();
    });
  }

  Future<WhatsAppComposeCubit> ready() async {
    final cubit = WhatsAppComposeCubit(recipients, preferences, whatsApp);
    await cubit.load();
    cubit.setText('Call me');
    return cubit;
  }

  test('uses the default delay and preselects the only recipient', () async {
    final cubit = await ready();
    expect(cubit.state.recipients, const Loaded([anu]));
    expect(cubit.state.recipientId, 'r1');
    expect(cubit.state.alertAfterMinutes, 30);
    expect(cubit.state.canSend, isTrue);
  });

  test('retrying after a network error reuses the request id, so WhatsApp gets it once', () async {
    final cubit = await ready();
    sendAnswers(() async => throw ApiException.network);
    await cubit.send();
    expect(cubit.state.status, ActionStatus.failed);

    sendAnswers(() async => message());
    await cubit.send();

    expect(cubit.state.status, ActionStatus.done);
    expect(requestIds.toSet(), hasLength(1));
  });

  test('a message WhatsApp rejected shows the reason and a retry is a new request', () async {
    final cubit = await ready();
    sendAnswers(() async => message(status: 'FAILED', error: 'Not on the allowed list'));
    await cubit.send();
    expect(cubit.state.error, 'Not on the allowed list');

    await cubit.send();
    expect(requestIds.toSet(), hasLength(2));
  });

  test('describes what happened to the SMS alert', () {
    expect(
      describeAlert(message(alert: {'id': 'a1', 'state': 'CANCELLED', 'note': 'Delivered on WhatsApp'})),
      'SMS alert not needed: Delivered on WhatsApp',
    );
    expect(
      describeAlert(message(alert: {'id': 'a1', 'state': 'SMS_ACCEPTED'})),
      'Not delivered in time · SMS sent by your relay phone',
    );
    expect(describeAlert(message(skipped: 'DAILY_RATE_LIMITED')), 'No SMS alert: daily alert limit reached');
    expect(describeAlert(message()), isNull);
  });
}
