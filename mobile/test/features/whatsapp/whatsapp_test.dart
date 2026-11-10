import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:offline_alert/core/bloc/resource.dart';
import 'package:offline_alert/core/network/api_exception.dart';
import 'package:offline_alert/features/preferences/domain/models/alert_preferences.dart';
import 'package:offline_alert/features/preferences/domain/repository/alert_preferences_repository.dart';
import 'package:offline_alert/features/recipients/domain/repository/recipient_repository.dart';
import 'package:offline_alert/features/settings/domain/models/profile.dart';
import 'package:offline_alert/features/settings/domain/repository/account_repository.dart';
import 'package:offline_alert/features/whatsapp/domain/models/whatsapp_message.dart';
import 'package:offline_alert/features/whatsapp/domain/repository/whatsapp_repository.dart';
import 'package:offline_alert/features/whatsapp/logic/whatsapp_compose_cubit/whatsapp_compose_cubit.dart';
import 'package:offline_alert/features/whatsapp/widgets/whatsapp_message_tile.dart';

import '../../fixtures.dart';

class _Recipients extends Mock implements RecipientRepository {}

class _Preferences extends Mock implements AlertPreferencesRepository {}

class _WhatsApp extends Mock implements WhatsAppRepository {}

class _Account extends Mock implements AccountRepository {}

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
  late _Account account;
  final requestIds = <String>[];
  final smsTexts = <String?>[];

  setUp(() {
    recipients = _Recipients();
    preferences = _Preferences();
    whatsApp = _WhatsApp();
    account = _Account();
    requestIds.clear();
    smsTexts.clear();
    when(() => recipients.list()).thenAnswer((_) async => [anu]);
    when(() => preferences.load()).thenAnswer((_) async => _prefs);
    when(() => account.load()).thenAnswer((_) async => const Profile(email: 'shop@example.com', displayName: 'Shop'));
  });

  void sendAnswers(Future<WaMessage> Function() answer) {
    when(
      () => whatsApp.send(
        clientRequestId: any(named: 'clientRequestId'),
        recipientId: any(named: 'recipientId'),
        text: any(named: 'text'),
        smsAlert: any(named: 'smsAlert'),
        alertAfterMinutes: any(named: 'alertAfterMinutes'),
        smsText: any(named: 'smsText'),
      ),
    ).thenAnswer((invocation) {
      requestIds.add(invocation.namedArguments[#clientRequestId] as String);
      smsTexts.add(invocation.namedArguments[#smsText] as String?);
      return answer();
    });
  }

  Future<WhatsAppComposeCubit> loaded() async {
    final cubit = WhatsAppComposeCubit(recipients, preferences, whatsApp, account);
    await cubit.load();
    return cubit;
  }

  Future<WhatsAppComposeCubit> ready() async {
    final cubit = await loaded();
    cubit.setText('Call me');
    return cubit;
  }

  test('starts with the default WhatsApp message and the default SMS from preferences', () async {
    final cubit = await loaded();
    expect(cubit.state.text, WhatsAppComposeState.defaultText);
    expect(cubit.state.smsText, 'Hi {name}');
    expect(cubit.state.messagePreview(anu), 'Hi Anu, this is a message from Shop.');
    expect(cubit.state.smsPreview(anu), 'Hi Anu');
    expect(cubit.state.canSend, isTrue);
  });

  test('sends the SMS text written for this message', () async {
    final cubit = await ready();
    cubit.setSmsText('  Please call {name} back, check {platform}  ');
    sendAnswers(() async => message());
    await cubit.send();
    expect(smsTexts, ['Please call {name} back, check {platform}']);
    expect(cubit.state.smsPreview(anu), 'Please call Anu back, check WhatsApp');
  });

  test('sends no SMS text when the SMS alert is off', () async {
    final cubit = await ready();
    cubit.setSmsAlert(false);
    sendAnswers(() async => message());
    await cubit.send();
    expect(smsTexts, [null]);
  });

  test('an empty SMS blocks sending only while the SMS alert is on', () async {
    final cubit = await ready();
    cubit.setSmsText('   ');
    expect(cubit.state.canSend, isFalse);
    cubit.setSmsAlert(false);
    expect(cubit.state.canSend, isTrue);
  });

  test('without the profile the preview uses the same name as the server', () async {
    when(() => account.load()).thenAnswer((_) async => throw ApiException.network);
    final cubit = await loaded();
    expect(cubit.state.recipients, const Loaded([anu]));
    expect(cubit.state.messagePreview(anu), 'Hi Anu, this is a message from Someone.');
  });

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
